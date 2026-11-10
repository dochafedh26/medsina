import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/medsina_logo.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/models/user_model.dart';
import '../../feedback/presentation/feedback_reviews_screen.dart';
import '../../subscription/presentation/referral_screen.dart';
import '../../subscription/presentation/subscription_paywall_screen.dart';
import '../../../core/services/user_study_progress_service.dart';

/// Predefined medical avatars with icons and color schemes
class MedicalAvatarPreset {
  final String id;
  final String label;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;

  const MedicalAvatarPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
  });

  static const List<MedicalAvatarPreset> presets = [
    MedicalAvatarPreset(
      id: 'preset:doctor_teal',
      label: 'Praticien Hospitalier',
      icon: Icons.medical_services_rounded,
      primaryColor: Color(0xFF0D9488),
      secondaryColor: Color(0xFF0F766E),
    ),
    MedicalAvatarPreset(
      id: 'preset:stethoscope_cyan',
      label: 'Clinicien Généraliste',
      icon: Icons.monitor_heart_rounded,
      primaryColor: Color(0xFF0284C7),
      secondaryColor: Color(0xFF0369A1),
    ),
    MedicalAvatarPreset(
      id: 'preset:resident_indigo',
      label: 'Résident Élite',
      icon: Icons.school_rounded,
      primaryColor: Color(0xFF6366F1),
      secondaryColor: Color(0xFF4338CA),
    ),
    MedicalAvatarPreset(
      id: 'preset:surgeon_rose',
      label: 'Chirurgien / Urgences',
      icon: Icons.health_and_safety_rounded,
      primaryColor: Color(0xFFE11D48),
      secondaryColor: Color(0xFFBE123C),
    ),
    MedicalAvatarPreset(
      id: 'preset:student_amber',
      label: 'Externe en Médecine',
      icon: Icons.local_library_rounded,
      primaryColor: Color(0xFFD97706),
      secondaryColor: Color(0xFFB45309),
    ),
    MedicalAvatarPreset(
      id: 'preset:pediatric_emerald',
      label: 'Pédiatrie & Soins',
      icon: Icons.child_care_rounded,
      primaryColor: Color(0xFF059669),
      secondaryColor: Color(0xFF047857),
    ),
    MedicalAvatarPreset(
      id: 'preset:cardio_purple',
      label: 'Cardiologie / Soins Intensifs',
      icon: Icons.favorite_rounded,
      primaryColor: Color(0xFF8B5CF6),
      secondaryColor: Color(0xFF6D28D9),
    ),
    MedicalAvatarPreset(
      id: 'preset:neuro_slate',
      label: 'Neuro / Universitaire',
      icon: Icons.psychology_rounded,
      primaryColor: Color(0xFF475569),
      secondaryColor: Color(0xFF1E293B),
    ),
  ];

  static MedicalAvatarPreset? findById(String? id) {
    if (id == null) return null;
    try {
      return presets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Reusable User Avatar Widget supporting custom photo URLs and preset medical avatars
class UserAvatarView extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const UserAvatarView({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.size = 54,
    this.onTap,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';
    final preset = MedicalAvatarPreset.findById(avatarUrl);

    Widget avatarContent;

    if (preset != null) {
      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [preset.primaryColor, preset.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: preset.primaryColor.withValues(alpha: 0.35),
              blurRadius: size * 0.25,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          preset.icon,
          size: size * 0.52,
          color: Colors.white,
        ),
      );
    } else if (avatarUrl != null && avatarUrl!.startsWith('http')) {
      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryTeal.withValues(alpha: 0.25),
              blurRadius: size * 0.2,
              offset: const Offset(0, 3),
            ),
          ],
          image: DecorationImage(
            image: NetworkImage(avatarUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (avatarUrl != null && avatarUrl!.startsWith('data:image')) {
      try {
        final base64Str = avatarUrl!.split(',').last;
        final bytes = base64Decode(base64Str);
        avatarContent = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (_) {
        avatarContent = _buildInitialAvatar(initial);
      }
    } else {
      avatarContent = _buildInitialAvatar(initial);
    }

    if (!showEditBadge) {
      if (onTap != null) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: avatarContent,
        );
      }
      return avatarContent;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: avatarContent,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppTheme.clinicalNavy, AppTheme.primaryTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

/// Modern Bento User Profile Screen (2026/2027 design)
class ModernUserProfileScreen extends StatefulWidget {
  const ModernUserProfileScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ModernUserProfileScreen()),
    );
  }

  @override
  State<ModernUserProfileScreen> createState() => _ModernUserProfileScreenState();
}

class _ModernUserProfileScreenState extends State<ModernUserProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _facultyController;
  late TextEditingController _phoneController;
  late TextEditingController _wilayaController;
  late TextEditingController _targetYearController;
  late TextEditingController _bioController;
  late TextEditingController _licenseKeyController;

  String _selectedMedicalRole = 'Candidat Résidanat';
  int? _selectedStudyYear;
  String? _currentAvatarUrl;

  final List<String> _medicalRoles = [
    'Candidat Résidanat',
    'Externe en Médecine',
    'Interne des Hôpitaux',
    'Médecin Résident',
    'Médecin Généraliste',
    'Praticien Spécialiste',
    'Enseignant Hospitalo-Universitaire',
  ];

  final List<String> _wilayasList = [
    '09 - Blida',
    '16 - Alger',
    '25 - Constantine',
    '31 - Oran',
    '23 - Annaba',
    '19 - Sétif',
    '15 - Tizi Ouzou',
    '05 - Batna',
    '22 - Sidi Bel Abbès',
    '13 - Tlemcen',
    '06 - Béjaïa',
    '10 - Bouira',
    '35 - Boumerdès',
    '44 - Aïn Defla',
    '26 - Médéa',
    '17 - Djelfa',
    '30 - Ouargla',
    '47 - Ghardaïa',
    'Autre Wilaya (1 à 58)',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _facultyController = TextEditingController(text: user?.faculty ?? 'Faculté de Médecine de Blida');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _wilayaController = TextEditingController(text: user?.wilaya ?? '09 - Blida');
    _targetYearController = TextEditingController(text: user?.residencyTargetYear ?? '2027');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _licenseKeyController = TextEditingController();

    _selectedMedicalRole = user?.medicalRole.isNotEmpty == true ? user!.medicalRole : 'Candidat Résidanat';
    _selectedStudyYear = user?.studyYear;
    _currentAvatarUrl = user?.avatarUrl;

    UserStudyProgressService.instance.initialize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _facultyController.dispose();
    _phoneController.dispose();
    _wilayaController.dispose();
    _targetYearController.dispose();
    _bioController.dispose();
    _licenseKeyController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_circle_rounded, color: AppTheme.primaryTeal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Personnaliser votre Avatar',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Option 1: File Picker (custom photo)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.clinicalNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.photo_library_rounded, size: 19),
                  label: const Text(
                    'Importer une Photo de Profil (Galerie)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _handleCustomPhotoUpload();
                  },
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.3))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OU CHOISIR UN AVATAR MÉDICAL 🩺',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.3))),
                ],
              ),
              const SizedBox(height: 14),

              // Option 2: Preset Medical Avatars Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: MedicalAvatarPreset.presets.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (ctx, index) {
                  final preset = MedicalAvatarPreset.presets[index];
                  final isSelected = _currentAvatarUrl == preset.id;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _updateAvatarUrl(preset.id);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? preset.primaryColor : Colors.transparent,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [preset.primaryColor, preset.secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(preset.icon, color: Colors.white, size: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preset.label.split(' ').first,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? preset.primaryColor : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCustomPhotoUpload() async {
    try {
      setState(() => _isUploadingAvatar = true);

      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (file == null) {
        setState(() => _isUploadingAvatar = false);
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _isUploadingAvatar = false);
        return;
      }

      final currentUser = context.read<AuthBloc>().state.user;
      final userId = currentUser?.id ?? 'guest';

      // 1. Try Supabase Storage upload
      String? uploadedUrl = await SupabaseService.uploadProfileAvatar(
        userId: userId,
        fileName: file.name,
        bytes: bytes,
      );

      // 2. If storage upload fails (e.g. offline), fallback to compact data URL
      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        final ext = file.name.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        final base64String = base64Encode(bytes);
        uploadedUrl = 'data:$mime;base64,$base64String';
      }

      _updateAvatarUrl(uploadedUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger la photo : $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  void _updateAvatarUrl(String newUrl) {
    setState(() => _currentAvatarUrl = newUrl);

    // Save immediately to user profile if not in full edit mode
    final user = context.read<AuthBloc>().state.user;
    if (user != null) {
      context.read<AuthBloc>().add(
            UpdateUserProfileEvent(
              fullName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : user.fullName,
              medicalRole: _selectedMedicalRole,
              faculty: _facultyController.text.trim().isNotEmpty ? _facultyController.text.trim() : user.faculty,
              studyYear: _selectedStudyYear,
              avatarUrl: newUrl,
              bio: _bioController.text.trim(),
              phone: _phoneController.text.trim(),
              wilaya: _wilayaController.text.trim(),
              residencyTargetYear: _targetYearController.text.trim(),
            ),
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo de profil mise à jour avec succès ✨'),
          backgroundColor: AppTheme.primaryTeal,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSaving = true);

    final user = context.read<AuthBloc>().state.user;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    context.read<AuthBloc>().add(
          UpdateUserProfileEvent(
            fullName: _nameController.text.trim(),
            medicalRole: _selectedMedicalRole,
            faculty: _facultyController.text.trim(),
            studyYear: _selectedStudyYear,
            avatarUrl: _currentAvatarUrl,
            bio: _bioController.text.trim(),
            phone: _phoneController.text.trim(),
            wilaya: _wilayaController.text.trim(),
            residencyTargetYear: _targetYearController.text.trim(),
          ),
        );

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vos modifications ont été enregistrées avec succès ! ✨'),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('Déconnexion'),
          ],
        ),
        content: const Text(
          'Êtes-vous certain de vouloir vous déconnecter de votre compte Medsina ?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              context.read<AuthBloc>().add(LogoutEvent());
            },
            child: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.user != null && !_isEditing) {
          final u = state.user!;
          _nameController.text = u.fullName;
          _facultyController.text = u.faculty;
          _phoneController.text = u.phone ?? '';
          _wilayaController.text = u.wilaya ?? '';
          _targetYearController.text = u.residencyTargetYear ?? '2027';
          _bioController.text = u.bio ?? '';
          _selectedMedicalRole = u.medicalRole.isNotEmpty ? u.medicalRole : _selectedMedicalRole;
          _selectedStudyYear = u.studyYear;
          _currentAvatarUrl = u.avatarUrl;
        }
      },
      builder: (context, authState) {
        final user = authState.user;
        final tier = user?.tier ?? SubscriptionTier.free;

        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
          appBar: AppBar(
            elevation: 0,
            title: const Text(
              'Espace Profil Médical',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            actions: [
              if (!_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 26, color: AppTheme.primaryTeal),
                  tooltip: 'Modifier mon profil',
                  onPressed: () => setState(() => _isEditing = true),
                )
              else
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  tooltip: 'Annuler la modification',
                  onPressed: () => setState(() => _isEditing = false),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // 1. Bento Header Card : Profile Identity & Status
                  _buildBentoHeaderCard(context, user, tier, isDark),

                  const SizedBox(height: 14),

                  // 2. Bento Card: Details & Editable Fields
                  _buildBentoDetailsCard(context, user, isDark),

                  const SizedBox(height: 14),

                  // 3. Bento Card: VIP Subscription & Key Activation
                  _buildBentoSubscriptionCard(context, user, tier, isDark),

                  const SizedBox(height: 14),

                  // 4. Bento Card: Statistics & Community Loyalty
                  _buildBentoStatsCard(context, user, isDark),

                  const SizedBox(height: 14),

                  // 5. Account Security & Logout
                  _buildBentoSecurityCard(context, isDark),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 1. Bento Header Card
  Widget _buildBentoHeaderCard(
    BuildContext context,
    UserModel? user,
    SubscriptionTier tier,
    bool isDark,
  ) {
    final userName = user?.fullName ?? 'Médecin';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.bentoCardDecoration(context, radius: 24),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with camera badge
              Stack(
                alignment: Alignment.center,
                children: [
                  UserAvatarView(
                    avatarUrl: _currentAvatarUrl ?? user?.avatarUrl,
                    name: userName,
                    size: 78,
                    showEditBadge: true,
                    onTap: _pickAvatar,
                  ),
                  if (_isUploadingAvatar)
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 18),
              // User identity & Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 17,
                          color: AppTheme.primaryTeal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tier.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tier.color.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded, size: 13, color: tier.color),
                              const SizedBox(width: 4),
                              Text(
                                tier.badgeText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: tier.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user?.residencyTargetYear != null && user!.residencyTargetYear!.isNotEmpty
                                ? 'Concours ${user.residencyTargetYear}'
                                : 'Session 2027',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (user?.bio?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, size: 16, color: AppTheme.primaryTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user!.bio!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 2. Bento Card: Details & Editable Fields
  Widget _buildBentoDetailsCard(BuildContext context, UserModel? user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.bentoCardDecoration(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.badge_rounded, color: AppTheme.primaryTeal, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Informations Médicales',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              if (!_isEditing)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryTeal,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  onPressed: () => setState(() => _isEditing = true),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (!_isEditing) ...[
            // View Mode
            _buildInfoRow(
              icon: Icons.person_rounded,
              label: 'Nom & Prénom',
              value: user?.fullName ?? 'Non renseigné',
              isDark: isDark,
            ),
            const Divider(height: 20),
            _buildInfoRow(
              icon: Icons.alternate_email_rounded,
              label: 'Adresse Email',
              value: user?.email.isNotEmpty == true ? user!.email : 'Non renseigné',
              isDark: isDark,
            ),
            const Divider(height: 20),
            _buildInfoRow(
              icon: Icons.medical_services_rounded,
              label: 'Rôle Médical',
              value: user?.medicalRole ?? 'Candidat Résidanat',
              isDark: isDark,
            ),
            const Divider(height: 20),
            _buildInfoRow(
              icon: Icons.account_balance_rounded,
              label: 'Faculté de Médecine',
              value: user?.faculty ?? 'Faculté de Blida',
              isDark: isDark,
            ),
            if (user?.studyYear != null) ...[
              const Divider(height: 20),
              _buildInfoRow(
                icon: Icons.local_library_rounded,
                label: 'Année d\'Étude (Externat)',
                value: '${user!.studyYear}ème Année',
                isDark: isDark,
              ),
            ],
            const Divider(height: 20),
            _buildInfoRow(
              icon: Icons.location_on_rounded,
              label: 'Wilaya',
              value: user?.wilaya ?? '09 - Blida',
              isDark: isDark,
            ),
            const Divider(height: 20),
            _buildInfoRow(
              icon: Icons.phone_android_rounded,
              label: 'Numéro de Téléphone',
              value: user?.phone?.isNotEmpty == true ? user!.phone! : 'Non renseigné',
              isDark: isDark,
            ),
            const Divider(height: 20),
            _buildInfoRow(
              icon: Icons.flag_rounded,
              label: 'Objectif Concours Résidanat',
              value: user?.residencyTargetYear?.isNotEmpty == true ? 'Session ${user!.residencyTargetYear}' : 'Session 2027',
              isDark: isDark,
            ),
          ] else ...[
            // Edit Mode Form
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom & Prénom',
                prefixIcon: Icon(Icons.person_rounded, size: 20),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Veuillez saisir votre nom' : null,
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _medicalRoles.contains(_selectedMedicalRole) ? _selectedMedicalRole : _medicalRoles.first,
              decoration: const InputDecoration(
                labelText: 'Rôle / Spécialité Médicale',
                prefixIcon: Icon(Icons.medical_services_rounded, size: 20),
              ),
              items: _medicalRoles.map((role) {
                return DropdownMenuItem(value: role, child: Text(role));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedMedicalRole = val);
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _facultyController,
              decoration: const InputDecoration(
                labelText: 'Faculté de Médecine',
                prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
                hintText: 'Ex: Faculté de Médecine de Blida',
              ),
            ),
            const SizedBox(height: 14),

            if (_selectedMedicalRole.contains('Externe') || _selectedMedicalRole.contains('Étudiant')) ...[
              DropdownButtonFormField<int>(
                value: _selectedStudyYear ?? 4,
                decoration: const InputDecoration(
                  labelText: 'Année d\'externat',
                  prefixIcon: Icon(Icons.local_library_rounded, size: 20),
                ),
                items: List.generate(6, (i) => i + 1).map((yr) {
                  return DropdownMenuItem(value: yr, child: Text('${yr}ème Année'));
                }).toList(),
                onChanged: (val) => setState(() => _selectedStudyYear = val),
              ),
              const SizedBox(height: 14),
            ],

            DropdownButtonFormField<String>(
              value: _wilayasList.contains(_wilayaController.text) ? _wilayaController.text : _wilayasList.first,
              decoration: const InputDecoration(
                labelText: 'Wilaya d\'exercice ou de résidence',
                prefixIcon: Icon(Icons.location_on_rounded, size: 20),
              ),
              items: _wilayasList.map((w) {
                return DropdownMenuItem(value: w, child: Text(w));
              }).toList(),
              onChanged: (val) {
                if (val != null) _wilayaController.text = val;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro de Téléphone (Optionnel)',
                prefixIcon: Icon(Icons.phone_android_rounded, size: 20),
                hintText: '05 / 06 / 07 ...',
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _targetYearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Session Résidanat Cible (Ex: 2027)',
                prefixIcon: Icon(Icons.flag_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _bioController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Devise médicale & Bio de motivation',
                prefixIcon: Icon(Icons.format_quote_rounded, size: 20),
                hintText: 'Ex: Major de promo 2027 incha\'Allah 🩺',
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isEditing = false),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
                    onPressed: _isSaving ? null : _saveProfile,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 3. Bento Card: VIP Subscription & Key Activation
  Widget _buildBentoSubscriptionCard(
    BuildContext context,
    UserModel? user,
    SubscriptionTier tier,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tier.color.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: tier.color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: tier.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.workspace_premium_rounded, color: tier.color, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier == SubscriptionTier.allAccess ? 'Medsina All-Access VIP' : tier.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: tier.color,
                        ),
                      ),
                      Text(
                        tier == SubscriptionTier.allAccess
                            ? 'Accès Intégral Illimité • Tout Inclus'
                            : 'Accès Illimité Medsina 2027',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Actif ✨',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Échéance du compte :',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${user?.subscriptionExpiry.day}/${user?.subscriptionExpiry.month}/${user?.subscriptionExpiry.year}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${user?.daysRemaining ?? 14} jours restants',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action buttons: Paywall + Referral
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: tier.color),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Tarifs & Packs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.group_add_rounded, size: 16),
                  label: const Text('Parrainer (+7j)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReferralScreen()),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // License Key Redemption Box
          const Text(
            'Activer un code d\'accès / Clé VIP',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _licenseKeyController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'MEDSINA-2027-VIP',
                    isDense: true,
                    prefixIcon: Icon(Icons.vpn_key_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.clinicalNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final code = _licenseKeyController.text.trim();
                  if (code.isNotEmpty) {
                    context.read<AuthBloc>().add(ActivateLicenseKeyEvent(licenseKey: code));
                    _licenseKeyController.clear();
                  }
                },
                child: const Text('Activer', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 4. Bento Card: Real-time Study & Activity Progress
  Widget _buildBentoStatsCard(BuildContext context, UserModel? user, bool isDark) {
    return ValueListenableBuilder<UserStudyProgress>(
      valueListenable: UserStudyProgressService.instance.progressNotifier,
      builder: (context, progress, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.bentoCardDecoration(context, radius: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.insights_rounded, color: Color(0xFFF59E0B), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Activité & Entraînement Medsina',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Progrès en direct • Objectifs quotidiens',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    tooltip: 'Ajuster mes objectifs quotidiens',
                    onPressed: () => _showDailyGoalsDialog(context, progress),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- 1. HERO ACTION: VALIDER MA JOURNÉE DE RÉVISION ("Accomplir le jour") ---
              _buildAccomplishDayHeroCard(context, progress, isDark),

              const SizedBox(height: 16),

              // --- 2. 7-DAY ACTIVITY HABIT TRACKER ---
              _buildWeeklyActivityTracker(context, progress, isDark),

              const SizedBox(height: 16),

              // --- 3. BENTO 4-STAT GRID: QCMS, COURS, SÉRIE, OBJECTIFS ---
              Row(
                children: [
                  Expanded(
                    child: _buildProgressStatItem(
                      icon: Icons.checklist_rounded,
                      title: 'QCMs Réalisés',
                      value: '${progress.totalQcmSolved}',
                      subtitle: '+${progress.todayQcmSolved} aujourd\'hui',
                      color: AppTheme.primaryTeal,
                      isDark: isDark,
                      badgeText: progress.todayQcmSolved > 0 ? 'Actif' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildProgressStatItem(
                      icon: Icons.menu_book_rounded,
                      title: 'Cours & Livrets',
                      value: '${progress.totalCoursesCompleted}',
                      subtitle: '+${progress.todayCoursesCompleted} aujourd\'hui',
                      color: const Color(0xFF6366F1),
                      isDark: isDark,
                      onTap: () => _showCompletedCoursesListDialog(context, progress),
                      badgeText: progress.completedCourseIds.isNotEmpty ? 'Liste' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildProgressStatItem(
                      icon: Icons.local_fire_department_rounded,
                      title: 'Série Active',
                      value: '${progress.currentStreak} j',
                      subtitle: 'Record : ${progress.maxStreak} jours 🔥',
                      color: const Color(0xFFEA580C),
                      isDark: isDark,
                      badgeText: progress.currentStreak >= 3 ? '🔥 Série' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildProgressGoalItem(
                      title: 'Objectif du jour',
                      qcmDone: progress.todayQcmSolved,
                      qcmGoal: progress.dailyQcmGoal,
                      courseDone: progress.todayCoursesCompleted,
                      courseGoal: progress.dailyCourseGoal,
                      isDark: isDark,
                      onTap: () => _showDailyGoalsDialog(context, progress),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // --- 4. ACTION BUTTONS: AJOUT MANUEL & VOIR COURS ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      icon: const Icon(Icons.add_task_rounded, size: 16, color: AppTheme.primaryTeal),
                      label: const Text(
                        'Enregistrer révision externe',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => _showAddExternalRevisionDialog(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    onPressed: () => _showCompletedCoursesListDialog(context, progress),
                    child: const Text('Mes Cours ➔', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Hero interactive card for validating today's study accomplishment
  Widget _buildAccomplishDayHeroCard(
    BuildContext context,
    UserStudyProgress progress,
    bool isDark,
  ) {
    final isAccomplished = progress.isTodayAccomplished;

    if (!isAccomplished) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488).withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              HapticFeedback.mediumImpact();
              final success = await UserStudyProgressService.instance.toggleTodayAccomplished();
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Journée validée avec succès ! +50 XP fidélité ajoutés ✨'),
                    backgroundColor: Color(0xFF059669),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valider ma Journée de Révision ✨',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Indiquer le jour accompli • +50 XP fidélité',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Accomplir ✅',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Already Accomplished today
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.task_alt_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Journée accomplie avec succès !',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                    ),
                    SizedBox(width: 4),
                    Text('🎉'),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Série active de ${progress.currentStreak} jour${progress.currentStreak > 1 ? "s" : ""} consécutif${progress.currentStreak > 1 ? "s" : ""} 🔥',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () async {
              await UserStudyProgressService.instance.toggleTodayAccomplished();
            },
            child: const Text('Modifier', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  /// Weekly 7-day visual activity habit loop
  Widget _buildWeeklyActivityTracker(
    BuildContext context,
    UserStudyProgress progress,
    bool isDark,
  ) {
    final now = DateTime.now();
    // Days of current week (Monday to Sunday)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
    final dayNames = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    int accomplishedCount = 0;
    for (final d in weekDays) {
      if (progress.isDateAccomplished(d)) accomplishedCount++;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SÉRIE DE CETTE SEMAINE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              Text(
                '$accomplishedCount / 7 jours validés (${((accomplishedCount / 7) * 100).toInt()}%)',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (idx) {
              final d = weekDays[idx];
              final isDone = progress.isDateAccomplished(d);
              final isToday = d.year == now.year && d.month == now.month && d.day == now.day;

              return Column(
                children: [
                  Text(
                    dayNames[idx],
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                      color: isToday
                          ? AppTheme.primaryTeal
                          : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? const Color(0xFF10B981)
                          : (isToday
                              ? AppTheme.primaryTeal.withValues(alpha: 0.15)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
                      border: isToday
                          ? Border.all(color: AppTheme.primaryTeal, width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: isDone
                        ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                        : (isToday
                            ? const Icon(Icons.star_rounded, size: 15, color: AppTheme.primaryTeal)
                            : Text(
                                '${d.day}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                ),
                              )),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStatItem({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
    String? badgeText,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressGoalItem({
    required String title,
    required int qcmDone,
    required int qcmGoal,
    required int courseDone,
    required int courseGoal,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final qcmPct = (qcmDone / (qcmGoal > 0 ? qcmGoal : 1)).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.flag_rounded, color: Color(0xFF0284C7), size: 18),
                  ),
                  Text(
                    '${(qcmPct * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$qcmDone / $qcmGoal QCMs',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: qcmPct,
                  minHeight: 5,
                  backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cours : $courseDone / $courseGoal fait',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dialog allowing students to manually record external study (polycopiés, hospital, library)
  void _showAddExternalRevisionDialog(BuildContext context) {
    final qcmController = TextEditingController(text: '15');
    final courseController = TextEditingController(text: '1');
    final specialtyController = TextEditingController(text: 'Cardiologie');

    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_task_rounded, color: AppTheme.primaryTeal),
            SizedBox(width: 10),
            Text('Révision Externe'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ajoutez vos QCMs et cours révisés sur polycopié, à la bibliothèque ou en stage hospitalier.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qcmController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre de QCMs faits',
                  prefixIcon: Icon(Icons.check_circle_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: courseController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre de Cours / Livrets étudiés',
                  prefixIcon: Icon(Icons.menu_book_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: specialtyController,
                decoration: const InputDecoration(
                  labelText: 'Discipline / Module révisé',
                  prefixIcon: Icon(Icons.category_rounded),
                  hintText: 'Ex: Cardiologie, Pneumologie...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            onPressed: () async {
              final q = int.tryParse(qcmController.text.trim()) ?? 0;
              final c = int.tryParse(courseController.text.trim()) ?? 0;
              final spec = specialtyController.text.trim();

              if (q > 0 || c > 0) {
                await UserStudyProgressService.instance.addManualStudyProgress(
                  qcmCount: q,
                  courseCount: c,
                  discipline: spec.isNotEmpty ? spec : null,
                );
                if (dlgContext.mounted) Navigator.pop(dlgContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Progrès enregistré : +$q QCMs et +$c cours ajoutés ! ✨'),
                      backgroundColor: AppTheme.primaryTeal,
                    ),
                  );
                }
              }
            },
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Dialog to customize daily study goals
  void _showDailyGoalsDialog(BuildContext context, UserStudyProgress progress) {
    final qcmGoalController = TextEditingController(text: '${progress.dailyQcmGoal}');
    final courseGoalController = TextEditingController(text: '${progress.dailyCourseGoal}');

    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: AppTheme.primaryTeal),
            SizedBox(width: 10),
            Text('Objectifs Quotidiens'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Définissez vos objectifs d\'entraînement journalier pour le Concours Résidanat.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: qcmGoalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Objectif QCMs / Jour',
                prefixIcon: Icon(Icons.flag_rounded),
                hintText: 'Ex: 25 ou 50',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: courseGoalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Objectif Cours / Jour',
                prefixIcon: Icon(Icons.menu_book_rounded),
                hintText: 'Ex: 1 ou 2',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            onPressed: () async {
              final q = int.tryParse(qcmGoalController.text.trim()) ?? 25;
              final c = int.tryParse(courseGoalController.text.trim()) ?? 1;

              await UserStudyProgressService.instance.updateDailyGoals(
                qcmGoal: q,
                courseGoal: c,
              );
              if (dlgContext.mounted) Navigator.pop(dlgContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Objectifs quotidiens mis à jour ! 🎯'),
                    backgroundColor: AppTheme.primaryTeal,
                  ),
                );
              }
            },
            child: const Text('Sauvegarder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Dialog displaying list of completed courses
  void _showCompletedCoursesListDialog(BuildContext context, UserStudyProgress progress) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = progress.completedCourseIds.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(sheetContext).size.height * 0.65,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cours & Livrets Accomplis',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${progress.totalCoursesCompleted} cours et livrets maîtrisés',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            if (list.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'Aucun cours validé pour le moment',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Révisez des cours dans le catalogue ou enregistrez une révision externe.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = list[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                      ),
                      title: Text(
                        item,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Maîtrisé • Validé dans le profil', style: TextStyle(fontSize: 10.5)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                        tooltip: 'Retirer de la liste',
                        onPressed: () async {
                          await UserStudyProgressService.instance.toggleCourseCompleted(item);
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 5. Account Security & Logout
  Widget _buildBentoSecurityCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.bentoCardDecoration(context, radius: 24),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            ),
            title: const Text('Noter Medsina & Témoigner', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Donnez votre avis pour faire évoluer l\'application', style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FeedbackReviewsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
            ),
            title: const Text(
              'Déconnexion du compte',
              style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDC2626), fontSize: 13.5),
            ),
            subtitle: const Text('Fermer la session sur cet appareil', style: TextStyle(fontSize: 11)),
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MedsinaLogo(height: 22),
              const SizedBox(width: 8),
              Text(
                'v${AppConstants.appVersion} • Sécurité & Chiffrement Cloud',
                style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
