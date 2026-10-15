import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/medsina_logo.dart';
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
  String _selectedRole = 'Candidat Résidanat';
  String _selectedFaculty = 'Faculté de Médecine de Blida';

  final List<String> _medicalRoles = [
    'Candidat Résidanat',
    'Externe (4e - 6e année)',
    'Interne en Médecine',
    'Médecin Résident',
    'Médecin Généraliste',
    'Médecin Spécialiste',
  ];

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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

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

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF0B0F19)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 500 : 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Brand Header
                      _buildBrandHeader(isDark),
                      const SizedBox(height: 24),

                      // Feature Highlights Pills
                      _buildHighlightsPills(isDark),
                      const SizedBox(height: 24),

                      // Auth Card with Tabs
                      Card(
                        elevation: isDark ? 0 : 4,
                        shadowColor: Colors.black.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Tabs
                              Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  indicator: BoxDecoration(
                                    color: AppTheme.primaryTeal,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  labelColor: Colors.white,
                                  unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade700,
                                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  tabs: const [
                                    Tab(text: 'Connexion'),
                                    Tab(text: 'Créer un Compte'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Tab Views
                              SizedBox(
                                height: 440,
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
                        ),
                      ),

                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_done_rounded, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            'Cloud Médical Sécurisé • Résidanat Blida 2027 v${AppConstants.appVersion}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
                : const Text('Créer mon Compte (14j Essai Gratuit)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ),
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

    context.read<AuthBloc>().add(
          RegisterSubmittedEvent(
            fullName: name,
            email: email,
            password: password,
            medicalRole: _selectedRole,
            faculty: _selectedFaculty,
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
}

