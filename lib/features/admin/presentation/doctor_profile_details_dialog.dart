import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/supabase_service.dart';
import '../models/admin_models.dart';

/// Modal dialog providing a complete 360° overview of a Doctor's account,
/// subscription, payments, medical credentials, and administrative actions.
class DoctorProfileDetailsDialog extends StatefulWidget {
  final AdminUserItem user;
  final bool isDark;
  final VoidCallback onManageSubscription;
  final VoidCallback onToggleBan;

  const DoctorProfileDetailsDialog({
    super.key,
    required this.user,
    required this.isDark,
    required this.onManageSubscription,
    required this.onToggleBan,
  });

  static Future<void> show({
    required BuildContext context,
    required AdminUserItem user,
    required bool isDark,
    required VoidCallback onManageSubscription,
    required VoidCallback onToggleBan,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DoctorProfileDetailsDialog(
        user: user,
        isDark: isDark,
        onManageSubscription: onManageSubscription,
        onToggleBan: onToggleBan,
      ),
    );
  }

  @override
  State<DoctorProfileDetailsDialog> createState() => _DoctorProfileDetailsDialogState();
}

class _DoctorProfileDetailsDialogState extends State<DoctorProfileDetailsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _deepDetails = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDeepDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDeepDetails() async {
    try {
      final data = await SupabaseService.fetchDoctorFullProfileDetails(
        userId: widget.user.id,
        userEmail: widget.user.email,
      );
      if (mounted) {
        setState(() {
          _deepDetails = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copié dans le presse-papier !'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'all_access':
        return const Color(0xFFEAB308); // Gold
      case 'resident_elite':
        return const Color(0xFF9333EA); // Purple
      case 'clinical_pro':
        return const Color(0xFF0284C7); // Sky Blue
      case 'etudiant':
        return const Color(0xFF2563EB); // Royal Blue
      default:
        return const Color(0xFF64748B); // Slate Grey
    }
  }

  String _getTierLabel(String tier) {
    switch (tier.toLowerCase()) {
      case 'all_access':
        return 'Medsina All-Access VIP';
      case 'resident_elite':
        return 'Pass Résident Élite';
      case 'clinical_pro':
        return 'Pass Clinique Pro';
      case 'etudiant':
        return 'Pass Étudiant Cursus';
      default:
        return 'Pass Découverte (Gratuit)';
    }
  }

  int? _resolveStudyYear(Map<String, dynamic> profile, AdminUserItem u) {
    if (profile['study_year'] != null) {
      final y = int.tryParse(profile['study_year'].toString());
      if (y != null && y >= 1 && y <= 6) return y;
    }
    if (u.studyYear != null && u.studyYear! >= 1 && u.studyYear! <= 6) {
      return u.studyYear;
    }

    final combinedRole = '${profile["medical_role"] ?? ""} ${u.medicalRole}';
    final match = RegExp(r'([1-6])\s*(?:e|è|eme|ère)?\s*ann', caseSensitive: false).firstMatch(combinedRole);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }

    final parenMatch = RegExp(r'\(\s*([1-6])', caseSensitive: false).firstMatch(combinedRole);
    if (parenMatch != null) {
      return int.tryParse(parenMatch.group(1) ?? '');
    }

    return null;
  }

  String _cleanMedicalRole(String rawRole, int? studyYear) {
    var cleaned = rawRole.trim();
    cleaned = cleaned.replaceAll('(e Année)', '').replaceAll('(e Annee)', '').replaceAll('(e année)', '').trim();

    if (cleaned.toLowerCase().contains('étudiant') || cleaned.toLowerCase().contains('etudiant')) {
      if (studyYear != null) {
        return 'Étudiant ($studyYear${studyYear == 1 ? "ère" : "ème"} Année)';
      } else {
        return 'Étudiant en Médecine';
      }
    }
    return cleaned.isNotEmpty ? cleaned : 'Praticien';
  }

  String _formatStudyYearDisplay(int? studyYear, String medicalRole) {
    if (studyYear != null) {
      return '$studyYear${studyYear == 1 ? "ère" : "ème"} Année d\'études';
    }
    final lower = medicalRole.toLowerCase();
    if (lower.contains('étudiant') || lower.contains('etudiant') || lower.contains('externe')) {
      return 'Étudiant (Année non renseignée)';
    }
    if (lower.contains('résident') || lower.contains('resident') || lower.contains('résidanat')) {
      return 'Médecin Résident (Spécialité)';
    }
    if (lower.contains('interne')) {
      return 'Interne en Médecine (7ème Année)';
    }
    return 'Diplômé / Praticien';
  }

  void _showEditStudyYearDialog(BuildContext context, int? currentYear, String currentRole) {
    int? selected = currentYear;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.school_rounded, color: AppTheme.primaryTeal),
              SizedBox(width: 10),
              Flexible(child: Text('Modifier Niveau / Année', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Niveau académique pour ${widget.user.fullName} :',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Année Universitaire',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1ère Année (Sciences Fondamentales I)')),
                  DropdownMenuItem(value: 2, child: Text('2ème Année (Sciences Fondamentales II)')),
                  DropdownMenuItem(value: 3, child: Text('3ème Année (Pré-Clinique & Sémiologie)')),
                  DropdownMenuItem(value: 4, child: Text('4ème Année (Externat - Pathologie I)')),
                  DropdownMenuItem(value: 5, child: Text('5ème Année (Externat - Pathologie II)')),
                  DropdownMenuItem(value: 6, child: Text('6ème Année (Externat - Thérapeutique)')),
                  DropdownMenuItem(value: null, child: Text('Diplômé / Résident / Praticien')),
                ],
                onChanged: (val) => setModalState(() => selected = val),
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
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      final newRole = selected != null
                          ? 'Étudiant (${selected}e Année)'
                          : (currentRole.contains('Étudiant') ? 'Médecin Généraliste' : currentRole);

                      final ok = await SupabaseService.updateUserStudyYear(
                        userId: widget.user.id,
                        studyYear: selected,
                        medicalRole: newRole,
                      );

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);

                      if (ok) {
                        setState(() {
                          if (_deepDetails['profile'] is Map) {
                            _deepDetails['profile']['study_year'] = selected;
                            _deepDetails['profile']['medical_role'] = newRole;
                          } else {
                            _deepDetails['profile'] = {
                              'study_year': selected,
                              'medical_role': newRole,
                            };
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF16A34A),
                            content: Text('Niveau académique mis à jour : ${selected != null ? "$selected" "e Année" : "Diplômé"}'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFFDC2626),
                            content: Text('Erreur lors de la mise à jour du niveau.'),
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final u = widget.user;
    final profile = (_deepDetails['profile'] as Map<String, dynamic>?) ?? {};
    final subscription = (_deepDetails['subscription'] as Map<String, dynamic>?) ?? {};
    final payments = (_deepDetails['payments'] as List?) ?? [];
    final licenseKeys = (_deepDetails['license_keys'] as List?) ?? [];

    final tierColor = _getTierColor(u.tier);
    final tierLabel = _getTierLabel(u.tier);
    final isBanned = u.isBanned;

    final referralCode = profile['referral_code']?.toString() ?? 'DR-${u.id.substring(0, 6).toUpperCase()}';
    final resolvedStudyYear = _resolveStudyYear(profile, u);
    final resolvedMedicalRole = _cleanMedicalRole(profile['medical_role']?.toString() ?? u.medicalRole, resolvedStudyYear);
    final studyYearDisplay = _formatStudyYearDisplay(resolvedStudyYear, resolvedMedicalRole);

    DateTime? effectiveExpiry = u.expiresAt;
    if (subscription['expires_at'] != null) {
      effectiveExpiry = DateTime.tryParse(subscription['expires_at'].toString()) ?? effectiveExpiry;
    }

    final isExpired = effectiveExpiry != null && DateTime.now().isAfter(effectiveExpiry);
    final daysRemaining = effectiveExpiry?.difference(DateTime.now()).inDays;

    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 16 : 28,
      ),
      child: Container(
        width: 760,
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.90),
        child: Column(
          children: [
            // --- TOP HEADER WITH DOCTOR IDENTITY ---
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large Doctor Avatar
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: isMobile ? 26 : 32,
                            backgroundColor: tierColor.withValues(alpha: 0.20),
                            child: Text(
                              u.fullName.trim().isNotEmpty
                                  ? u.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                                  : 'DR',
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.bold,
                                color: tierColor,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: isBanned
                                    ? const Color(0xFFDC2626)
                                    : (isExpired ? Colors.grey : const Color(0xFF16A34A)),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(
                                isBanned ? Icons.block_rounded : Icons.check,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // Names & Credentials
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    u.fullName.startsWith('Dr') ? u.fullName : 'Dr. ${u.fullName}',
                                    style: TextStyle(
                                      fontSize: isMobile ? 17 : 20,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: tierColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: tierColor.withValues(alpha: 0.40)),
                                  ),
                                  child: Text(
                                    tierLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: tierColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$resolvedMedicalRole • ${u.faculty}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                InkWell(
                                  onTap: () => _copyToClipboard(u.email, 'Email'),
                                  borderRadius: BorderRadius.circular(4),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: isMobile ? 180 : 280),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.email_outlined, size: 13, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            u.email,
                                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.copy_rounded, size: 11, color: Colors.grey.shade400),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _copyToClipboard(u.id, 'UUID'),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fingerprint_rounded, size: 13, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text('ID: ${u.id.substring(0, 8)}...', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                                      const SizedBox(width: 4),
                                      Icon(Icons.copy_rounded, size: 11, color: Colors.grey.shade400),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 20,
                      ),
                    ],
                  ),

                  // Warning banners if banned or has rejections
                  if (isBanned || u.rejectedPaymentsCount > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isBanned
                            ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isBanned ? const Color(0xFFDC2626) : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isBanned ? Icons.gavel_rounded : Icons.warning_amber_rounded,
                            size: 16,
                            color: isBanned ? const Color(0xFFDC2626) : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isBanned
                                  ? 'COMPTE SUSPENDU : ${u.banReason ?? 'Motif non spécifié'}'
                                  : 'ATTENTION : ${u.rejectedPaymentsCount}/3 paiements rejetés pour ce compte.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isBanned ? const Color(0xFFDC2626) : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // --- TAB BAR NAVIGATION ---
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: isMobile,
                labelColor: AppTheme.primaryTeal,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade600,
                indicatorColor: AppTheme.primaryTeal,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Identité & Cursus'),
                  Tab(icon: Icon(Icons.workspace_premium_outlined, size: 18), text: 'Abonnement'),
                  Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Paiements CCP'),
                  Tab(icon: Icon(Icons.vpn_key_outlined, size: 18), text: 'Licences & Quotas'),
                ],
              ),
            ),

            // --- TAB CONTENT BODY ---
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2.5),
                          SizedBox(height: 12),
                          Text('Chargement du profil complet du médecin...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildIdentityTab(u, profile, isDark, referralCode, resolvedMedicalRole, studyYearDisplay, resolvedStudyYear),
                        _buildSubscriptionTab(u, subscription, isDark, effectiveExpiry, daysRemaining, isExpired),
                        _buildPaymentsTab(payments, isDark),
                        _buildLicensesAndQuotasTab(licenseKeys, _deepDetails['trial_quotas'], isDark),
                      ],
                    ),
            ),

            // --- FOOTER ACTIONS ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                          label: const Text('Gérer Abonnement', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onManageSubscription();
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: isBanned ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  side: BorderSide(color: isBanned ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                ),
                                icon: Icon(isBanned ? Icons.lock_open_rounded : Icons.block_rounded, size: 15),
                                label: Text(isBanned ? 'Débannir' : 'Suspendre', style: const TextStyle(fontSize: 12)),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onToggleBan();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Fermer', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isBanned ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            side: BorderSide(color: isBanned ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                          ),
                          icon: Icon(isBanned ? Icons.lock_open_rounded : Icons.block_rounded, size: 16),
                          label: Text(isBanned ? 'Débannir' : 'Suspendre'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onToggleBan();
                          },
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Fermer'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                          label: const Text('Gérer / Prolonger Abonnement'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onManageSubscription();
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: IDENTITY & MEDICAL CAREER ---
  Widget _buildIdentityTab(
    AdminUserItem u,
    Map<String, dynamic> profile,
    bool isDark,
    String referralCode,
    String resolvedRole,
    String yearDisplay,
    int? resolvedYear,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('Profil Médical & Académique', Icons.local_hospital_outlined, isDark),
        const SizedBox(height: 12),
        _buildInfoGrid([
          _InfoTile('Rôle Médical', resolvedRole, Icons.medical_services_outlined, isDark),
          _InfoTile('Faculté de Médecine', u.faculty, Icons.school_outlined, isDark),
          _InfoTile(
            'Niveau / Année',
            yearDisplay,
            Icons.timeline_outlined,
            isDark,
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 15, color: AppTheme.primaryTeal),
              tooltip: 'Modifier le Niveau',
              onPressed: () => _showEditStudyYearDialog(context, resolvedYear, resolvedRole),
              splashRadius: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          _InfoTile('Code Parrainage', referralCode, Icons.loyalty_outlined, isDark, onCopy: () => _copyToClipboard(referralCode, 'Code Parrainage')),
        ]),

        const SizedBox(height: 20),
        _buildSectionHeader('Détails du Compte & Sécurité', Icons.security_outlined, isDark),
        const SizedBox(height: 12),
        _buildInfoGrid([
          _InfoTile('Email Officiel', u.email, Icons.alternate_email_outlined, isDark, onCopy: () => _copyToClipboard(u.email, 'Email')),
          _InfoTile('Identifiant Unique (UUID)', u.id, Icons.vpn_key_outlined, isDark, onCopy: () => _copyToClipboard(u.id, 'UUID')),
          _InfoTile(
            'Date d\'Inscription',
            u.createdAt != null ? DateFormat('dd/MM/yyyy à HH:mm').format(u.createdAt!.toLocal()) : 'Inconnue',
            Icons.calendar_today_outlined,
            isDark,
          ),
          _InfoTile(
            'Dernière Mise à Jour',
            profile['updated_at'] != null ? DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.parse(profile['updated_at']).toLocal()) : 'Jamais',
            Icons.update_outlined,
            isDark,
          ),
          _InfoTile('Rôle Système', u.isAdmin ? '👑 ADMINISTRATEUR' : 'Utilisateur Médecin', Icons.admin_panel_settings_outlined, isDark),
          _InfoTile(
            'Historique Rejets CCP',
            '${u.rejectedPaymentsCount} rejet(s) enregistré(s)',
            Icons.rule_folder_outlined,
            isDark,
            valueColor: u.rejectedPaymentsCount > 0 ? Colors.orange : null,
          ),
        ]),
      ],
    );
  }

  // --- TAB 2: SUBSCRIPTION & ENTITLEMENTS ---
  Widget _buildSubscriptionTab(
    AdminUserItem u,
    Map<String, dynamic> sub,
    bool isDark,
    DateTime? effectiveExpiry,
    int? daysRemaining,
    bool isExpired,
  ) {
    final tierColor = _getTierColor(u.tier);
    final maxDevices = sub['max_devices'] ?? 3;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('Formule & Statut d\'Accès Actuel', Icons.card_membership_outlined, isDark),
        const SizedBox(height: 12),

        // Plan Highlight Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tierColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tierColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.stars_rounded, color: tierColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTierLabel(u.tier),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      u.tier == 'free'
                          ? 'Accès découverte limité aux modules et 50 QCMs.'
                          : 'Accès complet avec mode 100% hors-ligne sur PC, Mobile et Web.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isExpired
                      ? Colors.grey
                      : (u.isBanned ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  u.isBanned
                      ? 'SUSPENDU'
                      : (isExpired ? 'EXPIRÉ' : 'ACTIF'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _buildInfoGrid([
          _InfoTile(
            'Date d\'Échéance',
            effectiveExpiry != null
                ? DateFormat('dd MMMM yyyy').format(effectiveExpiry.toLocal())
                : 'Durée illimitée',
            Icons.event_outlined,
            isDark,
          ),
          _InfoTile(
            'Compte à Rebours',
            daysRemaining != null
                ? (daysRemaining > 0 ? '$daysRemaining jour(s) restants' : 'Abonnement expiré')
                : 'Illimité',
            Icons.hourglass_bottom_outlined,
            isDark,
            valueColor: (daysRemaining != null && daysRemaining <= 7) ? Colors.orange : null,
          ),
          _InfoTile(
            'Appareils Simultanés',
            '$maxDevices écrans autorisés (Mode Hors-Ligne)',
            Icons.devices_outlined,
            isDark,
          ),
          _InfoTile(
            'Tuteurs IA Inclus',
            u.tier == 'all_access' ? '6 Agents IA Dédiés (Illimités)' : (u.tier == 'free' ? '1 requête test' : 'Tuteurs selon niveau'),
            Icons.psychology_outlined,
            isDark,
          ),
        ]),

        const SizedBox(height: 20),
        _buildSectionHeader('Options d\'Abonnement Disponibles', Icons.tune_rounded, isDark),
        const SizedBox(height: 8),
        Text(
          'Les tarifs promotionnels actuels (Plan Étudiant 500 DA/m, Clinique Pro 600 DA/m, Résident Élite 700 DA/m, All Accès VIP 800 DA/m) peuvent être attribués manuellement à ce médecin en cliquant sur le bouton ci-dessous.',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
        ),
      ],
    );
  }

  // --- TAB 3: PAYMENTS & CCP RECEIPTS ---
  Widget _buildPaymentsTab(List payments, bool isDark) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text('Aucune transaction ou reçu soumis par ce médecin.', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: payments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = payments[index] as Map<String, dynamic>;
        final amount = p['amount'] ?? 0;
        final status = (p['status'] ?? 'pending').toString().toLowerCase();
        final method = p['payment_method'] ?? 'CCP / Baridimob';
        final ref = p['receipt_reference'] ?? 'Réf. inconnue';
        final createdAt = p['created_at'] != null ? DateTime.tryParse(p['created_at'].toString()) : null;
        final receiptUrl = p['receipt_url'];

        Color statusColor;
        String statusLabel;
        switch (status) {
          case 'approved':
            statusColor = const Color(0xFF16A34A);
            statusLabel = 'Validé';
            break;
          case 'rejected':
            statusColor = const Color(0xFFDC2626);
            statusLabel = 'Rejeté';
            break;
          default:
            statusColor = Colors.orange;
            statusLabel = 'En attente';
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$amount DZD',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toLocal()) : '',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Méthode : $method • Réf : $ref',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade700),
              ),
              if (p['admin_notes'] != null && p['admin_notes'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Note Admin : ${p['admin_notes']}',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.orange),
                ),
              ],
              if (receiptUrl != null && receiptUrl.toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.attachment_rounded, size: 14),
                    label: const Text('Voir le Reçu', style: TextStyle(fontSize: 11.5)),
                    onPressed: () => _copyToClipboard(receiptUrl.toString(), 'Lien du reçu'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- TAB 4: LICENSES & QUOTAS ---
  Widget _buildLicensesAndQuotasTab(List keys, dynamic quotas, bool isDark) {
    final prof = _deepDetails['profile'] as Map<String, dynamic>?;
    final loyalty = _deepDetails['loyalty'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('Clés d\'Activation & Licences', Icons.vpn_key_outlined, isDark),
        const SizedBox(height: 10),
        if (keys.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Aucune clé de licence physique utilisée pour le moment.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          )
        else
          ...keys.map((k) {
            final keyMap = k as Map<String, dynamic>;
            final code = keyMap['key_code'] ?? '';
            final tier = keyMap['tier'] ?? 'inconnu';
            final days = keyMap['duration_days'] ?? 0;
            final redeemedAt = keyMap['redeemed_at'] != null ? DateTime.tryParse(keyMap['redeemed_at'].toString()) : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_rounded, size: 18, color: AppTheme.primaryTeal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
                        Text('Plan : $tier • Durée : $days jours', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  if (redeemedAt != null)
                    Text(DateFormat('dd/MM/yyyy').format(redeemedAt.toLocal()), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            );
          }),

        const SizedBox(height: 20),
        _buildSectionHeader('Statistiques d\'Utilisation des Outils', Icons.analytics_outlined, isDark),
        const SizedBox(height: 12),
        _buildInfoGrid([
          _InfoTile('QCMs Traités', '${_deepDetails['qcm_count'] ?? 0} questions répondues', Icons.quiz_outlined, isDark),
          _InfoTile(
            'Taux de Réussite QCM',
            (_deepDetails['qcm_count'] != null && _deepDetails['qcm_count'] > 0)
                ? '${(((_deepDetails['qcm_correct'] ?? 0) / _deepDetails['qcm_count']) * 100).toStringAsFixed(1)}%'
                : 'Non débuté',
            Icons.score_outlined,
            isDark,
          ),
          _InfoTile(
            'Analyses Vidal Effectuées',
            quotas != null ? '${quotas['prescription_analyses_used'] ?? 0} requête(s)' : '0 requête',
            Icons.medication_outlined,
            isDark,
          ),
          _InfoTile(
            'Requêtes Assistant Copilot',
            quotas != null ? '${quotas['copilot_queries_used'] ?? 0} échange(s)' : '0 échange',
            Icons.smart_toy_outlined,
            isDark,
          ),
        ]),
        const SizedBox(height: 18),
        _buildSectionHeader('Programme de Fidélité & Connexions', Icons.local_fire_department_outlined, isDark),
        const SizedBox(height: 12),
        _buildInfoGrid([
          _InfoTile(
            'Total Connexions',
            '${prof?['connection_count'] ?? loyalty?['connection_count'] ?? 1} session(s)',
            Icons.login_rounded,
            isDark,
          ),
          _InfoTile(
            'Série Active (Streak)',
            '${prof?['streak_days'] ?? loyalty?['streak_days'] ?? 1} jour(s) consécutif(s) 🔥',
            Icons.local_fire_department_rounded,
            isDark,
          ),
          _InfoTile(
            'Record de Série',
            '${prof?['max_streak_days'] ?? loyalty?['max_streak_days'] ?? 1} jour(s) ininterrompu(s)',
            Icons.emoji_events_outlined,
            isDark,
          ),
          _InfoTile(
            'Rang & Points XP',
            '${prof?['loyalty_level'] ?? loyalty?['loyalty_level'] ?? 'Externe Studieux'} (${prof?['loyalty_points'] ?? loyalty?['loyalty_points'] ?? 10} XP)',
            Icons.military_tech_rounded,
            isDark,
          ),
        ]),
      ],
    );
  }

  // --- REUSABLE UI HELPERS ---
  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryTeal),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 450;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children.map((c) {
            return SizedBox(
              width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 10) / 2,
              child: c,
            );
          }).toList(),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final Color? valueColor;
  final VoidCallback? onCopy;
  final Widget? trailing;

  const _InfoTile(this.label, this.value, this.icon, this.isDark, {this.valueColor, this.onCopy, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ?trailing,
          if (onCopy != null) ...[
            if (trailing != null) const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 13),
              color: Colors.grey.shade400,
              onPressed: onCopy,
              splashRadius: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}
