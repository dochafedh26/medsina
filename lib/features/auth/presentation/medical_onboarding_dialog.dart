import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/focus_mode_service.dart';
import '../../../core/services/funnel_analytics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../revision/utils/daily_quick_win_launcher.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../models/user_model.dart';

class MedicalOnboardingDialog extends StatefulWidget {
  final UserModel user;

  const MedicalOnboardingDialog({
    super.key,
    required this.user,
  });

  static String donePrefKey(String userId) => 'medsina_onboarding_done_$userId';
  static String goalPrefKey(String userId) => 'medsina_daily_qcm_goal_$userId';

  static Future<bool> shouldShowForUser(UserModel user) async {
    if (user.id.isEmpty || user.id.startsWith('demo_')) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(donePrefKey(user.id)) == true) return false;
    // Show if studyYear is not yet set (e.g. fresh Google OAuth login or incomplete signup)
    return user.studyYear == null;
  }

  static Future<void> show(
    BuildContext context, {
    required UserModel user,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MedicalOnboardingDialog(user: user),
    );
    if (result != null && result['launchFirstWin'] == true && context.mounted) {
      await DailyQuickWinLauncher.launch(
        context,
        questionCount: 5,
        source: 'onboarding_first_win',
        role: result['role'] as String?,
      );
    }
  }

  @override
  State<MedicalOnboardingDialog> createState() => _MedicalOnboardingDialogState();
}

class _MedicalOnboardingDialogState extends State<MedicalOnboardingDialog> {
  int _step = 0;
  late String _selectedRole;
  late int _selectedStudyYear;
  late String _selectedFaculty;
  late String _selectedTargetYear;
  int _dailyQcmGoal = 20;
  bool _isSaving = false;

  static const List<Map<String, dynamic>> _roles = [
    {
      'title': 'Candidat Résidanat',
      'subtitle': 'Préparation intensive au concours national',
      'icon': Icons.workspace_premium_rounded,
      'defaultYear': 6,
    },
    {
      'title': 'Externe en Médecine',
      'subtitle': 'Modules cliniques, stages & EMD (3e - 6e année)',
      'icon': Icons.local_hospital_rounded,
      'defaultYear': 4,
    },
    {
      'title': 'Interne / Médecin Généraliste',
      'subtitle': 'Gardes, urgences, protocoles CAT & ordonnances',
      'icon': Icons.medical_services_rounded,
      'defaultYear': 6,
    },
    {
      'title': 'Étudiant Pré-clinique',
      'subtitle': 'Fondamentaux (1ère & 2ème année médecine)',
      'icon': Icons.menu_book_rounded,
      'defaultYear': 2,
    },
  ];

  static const List<String> _faculties = [
    'Faculté de Médecine de Blida',
    'Faculté de Médecine d\'Alger',
    'Faculté de Médecine d\'Oran',
    'Faculté de Médecine de Constantine',
    'Faculté de Médecine d\'Annaba',
    'Faculté de Médecine de Sétif',
    'Faculté de Médecine de Tizi Ouzou',
    'Faculté de Médecine de Batna',
    'Faculté de Médecine de Sidi Bel Abbès',
    'Faculté de Médecine de Tlemcen',
    'Faculté de Médecine de Béjaïa',
    'Faculté de Médecine de Ouargla',
    'Faculté de Médecine de Mostaganem',
    'Autre Faculté / Université',
  ];

  static const List<String> _targetYears = ['2026', '2027', '2028', 'Non concerné'];
  static const List<int> _goalOptions = [10, 20, 30, 50];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.medicalRole.isNotEmpty
        ? widget.user.medicalRole
        : 'Candidat Résidanat';
    _selectedStudyYear = widget.user.studyYear ?? 6;
    _selectedFaculty = _faculties.contains(widget.user.faculty)
        ? widget.user.faculty
        : 'Faculté de Médecine de Blida';
    _selectedTargetYear = widget.user.residencyTargetYear ?? '2027';
  }

  Future<void> _skipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(MedicalOnboardingDialog.donePrefKey(widget.user.id), true);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(MedicalOnboardingDialog.donePrefKey(widget.user.id), true);
      await prefs.setInt(MedicalOnboardingDialog.goalPrefKey(widget.user.id), _dailyQcmGoal);

      if (!FocusModeService.instance.isEnabled) {
        final lowerRole = _selectedRole.toLowerCase();
        final presetLabel = (lowerRole.contains('interne') ||
                lowerRole.contains('médecin') ||
                lowerRole.contains('medecin') ||
                lowerRole.contains('praticien'))
            ? 'Réanimation & Urgences'
            : 'Cardiologie';
        await FocusModeService.instance.enableFocus(label: presetLabel);
      }

      FunnelAnalyticsService.instance.trackOnboardingCompleted(
        role: _selectedRole,
        faculty: _selectedFaculty,
        studyYear: _selectedStudyYear,
        targetYear: _selectedTargetYear,
        dailyGoal: _dailyQcmGoal,
      );

      if (mounted) {
        context.read<AuthBloc>().add(
          UpdateUserProfileEvent(
            fullName: widget.user.fullName,
            medicalRole: _selectedRole,
            faculty: _selectedFaculty,
            studyYear: _selectedStudyYear,
            avatarUrl: widget.user.avatarUrl,
            bio: widget.user.bio,
            phone: widget.user.phone,
            wilaya: widget.user.wilaya,
            residencyTargetYear: _selectedTargetYear == 'Non concerné'
                ? null
                : _selectedTargetYear,
          ),
        );
        setState(() => _step = 3);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = width > 560 ? 520.0 : width * 0.92;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.clinicalNavy, AppTheme.primaryTeal],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue, ${widget.user.fullName.split(' ').first} !',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _step == 3
                              ? 'Configuration terminée • Prêt pour votre 1er QCM'
                              : 'Étape ${_step + 1} sur 3 • Personnalisation médicale',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_step < 3)
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: const Text('Passer', style: TextStyle(fontSize: 12.5)),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Step progress bar
              Row(
                children: List.generate(3, (index) {
                  final active = _step >= 3 || index <= _step;
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: active
                            ? AppTheme.primaryTeal
                            : (isDark ? Colors.white12 : Colors.grey.shade200),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  child: _buildStepContent(isDark),
                ),
              ),
              const SizedBox(height: 20),

              // Footer buttons
              if (_step == 3)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop<Map<String, dynamic>>({
                          'launchFirstWin': true,
                          'role': _selectedRole,
                        });
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text(
                        'Lancer mon 1er QCM (5 questions • 3 min)',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop<Map<String, dynamic>>({
                          'launchFirstWin': false,
                        });
                      },
                      child: const Text(
                        'Accéder au tableau de bord',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_step > 0)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _step -= 1),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Précédent'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () {
                              if (_step < 2) {
                                setState(() => _step += 1);
                              } else {
                                _completeOnboarding();
                              }
                            },
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _step < 2
                                  ? Icons.arrow_forward_rounded
                                  : Icons.check_circle_rounded,
                              size: 18,
                            ),
                      label: Text(
                        _step < 2 ? 'Continuer' : 'Terminer la configuration',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quel est votre cursus actuel ?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ..._roles.map((r) {
              final title = r['title'] as String;
              final selected = _selectedRole == title;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() {
                    _selectedRole = title;
                    _selectedStudyYear = r['defaultYear'] as int;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: selected
                          ? AppTheme.primaryTeal.withValues(alpha: 0.12)
                          : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primaryTeal
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                        width: selected ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          r['icon'] as IconData,
                          color: selected ? AppTheme.primaryTeal : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: selected ? AppTheme.primaryTeal : null,
                                ),
                              ),
                              Text(
                                r['subtitle'] as String,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle_rounded, color: AppTheme.primaryTeal),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'Année d\'étude',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(6, (idx) {
                final year = idx + 1;
                final selected = _selectedStudyYear == year;
                return ChoiceChip(
                  label: Text('${year}${year == 1 ? "ère" : "ème"} année'),
                  selected: selected,
                  selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _selectedStudyYear = year),
                );
              }),
            ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Votre Faculté de Médecine',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Permet d\'adapter les annales, livrets et statistiques à votre faculté.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _selectedFaculty,
              isExpanded: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.account_balance_rounded, color: AppTheme.primaryTeal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: _faculties
                  .map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedFaculty = val);
              },
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cible du Concours & Objectif Quotidien',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            const Text(
              'Année cible du Résidanat',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _targetYears.map((y) {
                final selected = _selectedTargetYear == y;
                return ChoiceChip(
                  label: Text(y),
                  selected: selected,
                  selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _selectedTargetYear = y),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Objectif quotidien de QCMs',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goalOptions.map((g) {
                final selected = _dailyQcmGoal == g;
                return ChoiceChip(
                  label: Text('$g QCMs / jour'),
                  selected: selected,
                  selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _dailyQcmGoal = g),
                );
              }).toList(),
            ),
          ],
        );

      default:
        final focusLabel = FocusModeService.instance.focusLabel ?? 'Cardiologie';
        final yearSuffix = _selectedStudyYear == 1 ? 'ère' : 'ème';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppTheme.primaryTeal.withValues(alpha: 0.24),
                          const Color(0xFF1E293B),
                        ]
                      : [
                          const Color(0xFFF0FDFA),
                          const Color(0xFFCCFBF1).withValues(alpha: 0.45),
                        ],
                ),
                border: Border.all(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.rocket_launch_rounded, color: AppTheme.primaryTeal, size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Votre espace est prêt ! 🚀',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '• Cursus : $_selectedRole ($_selectedStudyYear$yearSuffix année)\n'
                    '• Faculté : $_selectedFaculty\n'
                    '• Objectif quotidien : $_dailyQcmGoal QCM / jour\n'
                    '• Mode Focus activé : $focusLabel',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: isDark ? Colors.grey.shade200 : const Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_rounded, color: Color(0xFFF59E0B), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Objectif J1 (plan 7 jours) : lancez 5 QCM rapides en 3 minutes pour valider votre 1ère session et activer votre série.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }
}
