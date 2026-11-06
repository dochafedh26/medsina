import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/medsina_logo.dart';
import '../../help/presentation/user_guide_pdf_viewer_screen.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for Login
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscurePassword = true;

  // Controllers for Register
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  bool _registerObscurePassword = true;
  String _selectedRole = 'Étudiant en Médecine';
  int _selectedStudyYear = 1;
  String _selectedFaculty = 'Faculté de Médecine de Blida';

  final List<String> _medicalRoles = [
    'Étudiant en Médecine',
    'Candidat Résidanat',
    'Interne en Médecine',
    'Médecin Résident',
    'Médecin Généraliste',
    'Médecin Spécialiste',
  ];

  final Map<int, String> _studyYears = {
    1: '1ère Année (Sciences Fondamentales I)',
    2: '2ème Année (Sciences Fondamentales II)',
    3: '3ème Année (Pré-clinique & Sémiologie)',
    4: '4ème Année (Externat - Pathologie I)',
    5: '5ème Année (Externat - Pathologie II)',
    6: '6ème Année (Externat - Thérapeutique & Spécialités)',
  };

  final List<String> _faculties = [
    'Faculté de Médecine de Blida',
    'Faculté de Médecine d\'Alger',
    'Faculté de Médecine de Constantine',
    'Faculté de Médecine d\'Oran',
    'Faculté de Médecine d\'Annaba',
    'Faculté de Médecine de Tlemcen',
    'Faculté de Médecine de Sétif',
    'Autre faculté',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopSplit = screenWidth >= 960;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.errorMessage!)),
                ],
              ),
            ),
          );
          context.read<AuthBloc>().add(ClearAuthMessageEvent());
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.successMessage!)),
                ],
              ),
            ),
          );
          context.read<AuthBloc>().add(ClearAuthMessageEvent());
        }
      },
      builder: (context, state) {
        final isLoading = state.status == AuthStatus.loading;

        final authBentoCard = Container(
          decoration: AppTheme.bentoCardDecoration(context, radius: 24),
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              // Pill-segmented Tabs
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: AppTheme.segmentedPillContainerDecoration(
                  context,
                  radius: 14,
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: isDark ? AppTheme.primaryTeal : AppTheme.clinicalNavy,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.clinicalNavy.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF475569),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Connexion'),
                    Tab(text: 'Créer un Compte'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tab Views
              SizedBox(
                height: 445,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoginForm(isLoading),
                    _buildRegisterForm(isLoading),
                  ],
                ),
              ),
            ],
          ),
        );

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF090D16), const Color(0xFF111827)]
                    : [const Color(0xFFF3F6FA), const Color(0xFFE6EEF8)],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktopSplit ? 40 : 20,
                  vertical: 32,
                ),
                child: isDesktopSplit
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildDesktopShowcasePanel(isDark),
                              ),
                              const SizedBox(width: 28),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    authBentoCard,
                                    const SizedBox(height: 16),
                                    _buildDownloadSection(isDark),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildBrandHeader(isDark),
                            const SizedBox(height: 20),
                            _buildHighlightsPills(isDark),
                            const SizedBox(height: 20),
                            authBentoCard,
                            const SizedBox(height: 16),
                            _buildDownloadSection(isDark),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_done_rounded, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Cloud Médical Sécurisé • Résidanat Blida 2027 v${AppConstants.appVersion}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopShowcasePanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: AppTheme.heroNavyDecoration(radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const MedsinaLogo.icon(size: 40),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MEDSINA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'CLINICAL & RESIDENCY SUITE • 2027',
                        style: TextStyle(
                          color: AppTheme.secondaryTeal.withValues(alpha: 0.95),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  '✨ ARCHITECTURE BENTO MÉDICALE • NOUVELLE GÉNÉRATION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'L\'Excellence Médicale,\ndu Cursus Universitaire\nà la Garde d\'Urgence.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Préparez le concours de Résidanat (Blida & Facultés Nationales) et sécurisez vos décisions cliniques au lit du malade grâce à une plateforme unifiée.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              _buildShowcaseFeatureTile(
                icon: Icons.school_rounded,
                title: '47 Modules & 6 240+ QCMs Corrigés',
                subtitle: 'Annales officielles, fiches synthétiques PDF & répétition espacée FSRS.',
              ),
              const SizedBox(height: 14),
              _buildShowcaseFeatureTile(
                icon: Icons.emergency_rounded,
                title: 'Pratique Clinique, CAT & DCI Algérie',
                subtitle: 'Arbres décisionnels MSPRH, scores validés & pharmacopée Saidal/IPA.',
              ),
              const SizedBox(height: 14),
              _buildShowcaseFeatureTile(
                icon: Icons.auto_awesome_rounded,
                title: 'MedsinaTeacher & Copilote Clinique IA',
                subtitle: 'Tuteur médical intelligent, simulateur de cas & analyseur biologique.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: AppTheme.secondaryTeal,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Synchronisation Cloud multi-appareils & Mode 100% Hors-Ligne • v${AppConstants.appVersion}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.secondaryTeal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.secondaryTeal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const MedsinaLogo.icon(size: 64),
        ),
        const SizedBox(height: 16),
        const MedsinaLogo(height: 38),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'PLATEFORME MÉDICALE GLOBALE & RÉSIDANAT 2027',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryTeal,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightsPills(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildPill(Icons.school_rounded, '47 Modules Blida 2027', isDark),
        _buildPill(Icons.emergency_rounded, 'CAT Urgences', isDark),
        _buildPill(Icons.calculate_rounded, 'Calculateurs Validés', isDark),
      ],
    );
  }

  Widget _buildPill(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primaryTeal),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isLoading) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Adresse Email',
            hintText: 'dr.nom@medsina.com',
            prefixIcon: Icon(Icons.email_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _loginPasswordController,
          obscureText: _loginObscurePassword,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _loginObscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _loginObscurePassword = !_loginObscurePassword),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showForgotPasswordDialog(context),
            child: const Text('Mot de passe oublié ?', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submitLogin,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Se Connecter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Authentification médicale sécurisée avec chiffrement de bout en bout et synchronisation multi-appareils.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(bool isLoading) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        if (AppConstants.isNovemberPromoActive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                  child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'OFFRE SPÉCIALE NOVEMBRE',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Jusqu\'au 30/11',
                            style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '1 Mois All-Access VIP Offert !',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Accès illimité aux 47 modules du Résidanat, QCMs, urgences et tuteurs MedsinaTeacher.',
                        style: TextStyle(color: Colors.white, fontSize: 11, height: 1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        TextField(
          controller: _registerNameController,
          decoration: const InputDecoration(
            labelText: 'Nom et Prénom',
            hintText: 'Dr. Sarah Amrani',
            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _registerEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Adresse Email',
            hintText: 'sarah.amrani@gmail.com',
            prefixIcon: Icon(Icons.email_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _registerPasswordController,
          obscureText: _registerObscurePassword,
          decoration: InputDecoration(
            labelText: 'Mot de passe (6 car. min.)',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _registerObscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _registerObscurePassword = !_registerObscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedRole,
          decoration: const InputDecoration(
            labelText: 'Statut Médical',
            prefixIcon: Icon(Icons.badge_outlined, size: 20),
          ),
          items: _medicalRoles
              .map((role) => DropdownMenuItem(value: role, child: Text(role, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (val) => setState(() => _selectedRole = val ?? _selectedRole),
        ),
        if (_selectedRole == 'Étudiant en Médecine') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedStudyYear,
            decoration: const InputDecoration(
              labelText: 'Année Universitaire d\'Étude',
              prefixIcon: Icon(Icons.school_outlined, size: 20, color: Color(0xFF2563EB)),
            ),
            items: _studyYears.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ))
                .toList(),
            onChanged: (val) => setState(() => _selectedStudyYear = val ?? _selectedStudyYear),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedFaculty,
          decoration: const InputDecoration(
            labelText: 'Faculté de Médecine',
            prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
          ),
          items: _faculties
              .map((fac) => DropdownMenuItem(value: fac, child: Text(fac, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (val) => setState(() => _selectedFaculty = val ?? _selectedFaculty),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submitRegister,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    AppConstants.isNovemberPromoActive
                        ? 'Créer mon Compte (1 Mois VIP Offert 🎁)'
                        : 'Créer mon Compte (14j Essai Gratuit)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        if (AppConstants.isNovemberPromoActive) ...[
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '⭐ Aucun paiement requis • Activation instantanée du Pass VIP 30 jours',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  void _submitLogin() {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();
    context.read<AuthBloc>().add(LoginSubmittedEvent(email: email, password: password));
  }

  void _submitRegister() {
    final name = _registerNameController.text.trim();
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner tous les champs obligatoires.')),
      );
      return;
    }

    final roleToSend = _selectedRole == 'Étudiant en Médecine'
        ? 'Étudiant (${_selectedStudyYear}e Année)'
        : _selectedRole;

    context.read<AuthBloc>().add(
          RegisterSubmittedEvent(
            fullName: name,
            email: email,
            password: password,
            medicalRole: roleToSend,
            faculty: _selectedFaculty,
            studyYear: _selectedRole == 'Étudiant en Médecine' ? _selectedStudyYear : null,
          ),
        );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailCtrl = TextEditingController(text: _loginEmailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppTheme.primaryTeal),
            SizedBox(width: 8),
            Text('Mot de passe oublié'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saisissez votre adresse email pour recevoir un lien sécurisé de réinitialisation de votre mot de passe.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', hintText: 'dr.nom@medsina.com'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(ctx);
                try {
                  await SupabaseService.resetPassword(email);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF16A34A),
                        content: Text('Un e-mail de réinitialisation a été envoyé à $email'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFFDC2626),
                        content: Text('Erreur: $e'),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Envoyer le lien'),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.teal.shade100,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.install_mobile_rounded, color: AppTheme.primaryTeal, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Installer l\'Application Medsina',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.blueGrey.shade900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'OFFLINE ⚡',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Profitez de la révision hors-ligne complète et de la fluidité native.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final buttons = [
                _buildDownloadButton(
                  title: 'Android APK',
                  subtitle: 'Mobile & Tablette',
                  badge: 'v${AppConstants.appVersion}',
                  icon: Icons.android_rounded,
                  accentColor: const Color(0xFF10B981),
                  isDark: isDark,
                  onTap: () => _openUrl(AppConstants.androidDownloadUrl),
                ),
                if (!isNarrow) const SizedBox(width: 10) else const SizedBox(height: 8),
                _buildDownloadButton(
                  title: 'Windows PC',
                  subtitle: 'Setup 64-bit Bureau',
                  badge: 'v${AppConstants.appVersion}',
                  icon: Icons.desktop_windows_rounded,
                  accentColor: const Color(0xFF0284C7),
                  isDark: isDark,
                  onTap: () => _openUrl(AppConstants.windowsDownloadUrl),
                ),
              ];

              if (isNarrow) {
                return Column(children: buttons);
              }
              return Row(
                children: [
                  Expanded(child: buttons[0]),
                  buttons[1],
                  Expanded(child: buttons[2]),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserGuidePdfViewerScreen()),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '📖 Découvrir Medsina : Lire le Guide Officiel (PDF)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: InkWell(
              onTap: () => _openUrl(AppConstants.releasesUrl),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Toutes les versions et mises à jour sur GitHub Releases',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.35),
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.blueGrey.shade900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.download_rounded, size: 16, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String urlStr) async {
    try {
      final uri = Uri.parse(urlStr);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir le lien : $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}
