import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../revision/data/residency_repository.dart';
import '../../revision/models/module_model.dart';
import '../../revision/models/qcm_model.dart';
import '../../whiteboard/presentation/whiteboard_list_screen.dart';
import '../models/teacher_earnings_model.dart';
import '../models/teacher_workspace_model.dart';
import '../services/teacher_earnings_service.dart';
import '../services/teacher_workspace_service.dart';

class TeacherWorkspaceScreen extends StatefulWidget {
  final int initialTab;
  const TeacherWorkspaceScreen({super.key, this.initialTab = 0});

  @override
  State<TeacherWorkspaceScreen> createState() => _TeacherWorkspaceScreenState();
}

class _TeacherWorkspaceScreenState extends State<TeacherWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TeacherPublicationItem> _publications = [];
  List<TeacherExamModel> _exams = [];
  List<MedicalModuleModel> _modules = [];
  String _specialtyFilter = 'Toutes';

  // Rémunération enseignante (65 % auteurs / 35 % plateforme)
  TeacherEarningsSummary _earnings = TeacherEarningsSummary.empty;
  bool _earningsLoading = true;

  // Studio Publication state
  AcademicRank _selectedRank = AcademicRank.resident;
  bool _canPublish = false;
  TeacherContentType _selectedContentType = TeacherContentType.course;
  String _pubSpecialty = 'Cardiologie';
  final _pubTitleCtrl = TextEditingController();
  final _pubSummaryCtrl = TextEditingController();
  final _pubBodyCtrl = TextEditingController();
  final List<TeacherFlashcardPair> _draftFlashcards = [];

  // Hybrid Exam Builder state
  String _examCategory = 'emd_externat';
  String _examSpecialty = 'Cardiologie';
  final _examTitleCtrl = TextEditingController();
  final _examDurationCtrl = TextEditingController(text: '45');
  final List<QcmQuestion> _pickedMedsinaQcms = [];
  final List<CustomExamQuestion> _draftCustomQuestions = [];

  @override
  void initState() {
    super.initState();
    // La publication est réservée aux enseignants dont le grade a été vérifié
    // par l'administration. La consultation du flux reste ouverte à tous.
    final user = context.read<AuthBloc>().state.user;
    _canPublish = user?.canPublishTeacherContent ?? false;
    _selectedRank = _rankFromProfile(user?.teacherRank) ??
        _rankFromMedicalRole(user?.medicalRole) ??
        AcademicRank.maitreAssistant;
    _tabController = TabController(
      length: _canPublish ? 5 : 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, _canPublish ? 4 : 1),
    );
    _loadAll();
  }

  /// Résout le grade vérifié fourni par le serveur (`teacher_rank`).
  static AcademicRank? _rankFromProfile(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final rank in AcademicRank.values) {
      if (rank.name == raw) return rank;
    }
    return null;
  }

  /// Repli pour les administrateurs (qui publient sans grade vérifié) :
  /// lecture du grade déclaré dans le profil.
  static AcademicRank? _rankFromMedicalRole(String? raw) {
    final role = (raw ?? '').toLowerCase();
    if (role.contains('professeur')) return AcademicRank.professeur;
    if (role.contains('mca') || role.contains('conférences') || role.contains('conferences')) {
      return AcademicRank.mca;
    }
    if (role.contains('maître') || role.contains('maitre')) return AcademicRank.maitreAssistant;
    if (role.contains('assistant')) return AcademicRank.assistant;
    if (role.contains('résident') || role.contains('resident')) return AcademicRank.resident;
    return null;
  }

  Future<void> _loadAll() async {
    final pubs = await TeacherWorkspaceService.loadPublications();
    final exams = await TeacherWorkspaceService.loadExams();
    final mods = await ResidencyRepository.loadModulesAsync();
    final earnings = _canPublish
        ? await TeacherEarningsService.loadSummary()
        : TeacherEarningsSummary.empty;
    if (mounted) {
      setState(() {
        _publications = pubs;
        _exams = exams;
        _modules = mods;
        _earnings = earnings;
        _earningsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pubTitleCtrl.dispose();
    _pubSummaryCtrl.dispose();
    _pubBodyCtrl.dispose();
    _examTitleCtrl.dispose();
    _examDurationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Espace Prof / Enseignant HU',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Résidents • Assistants • Maîtres-Assistants • Professeurs',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.primaryTeal,
          labelColor: AppTheme.primaryTeal,
          tabs: [
            const Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Cours & Ressources'),
            const Tab(icon: Icon(Icons.quiz_rounded, size: 18), text: 'Examens EMD & Concours'),
            if (_canPublish) ...[
              const Tab(icon: Icon(Icons.edit_note_rounded, size: 18), text: 'Publier (Prof)'),
              const Tab(icon: Icon(Icons.add_chart_rounded, size: 18), text: 'Créer Examen / QROC'),
              const Tab(icon: Icon(Icons.payments_rounded, size: 18), text: 'Mes gains'),
            ],
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPublicationsFeedTab(),
          _buildExamsListTab(),
          if (_canPublish) ...[
            _buildPublishStudioTab(),
            _buildExamBuilderTab(),
            _buildEarningsTab(),
          ],
        ],
      ),
    );
  }

  // TAB 1 : Flux des publications enseignants
  Widget _buildPublicationsFeedTab() {
    final specialties = ['Toutes', ..._publications.map((p) => p.specialty).toSet()];
    final filtered = _publications.where((p) {
      if (_specialtyFilter == 'Toutes') return true;
      return p.specialty == _specialtyFilter;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: specialties.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final sp = specialties[idx];
              final sel = sp == _specialtyFilter;
              return ChoiceChip(
                label: Text(sp, style: TextStyle(fontWeight: FontWeight.w800, color: sel ? Colors.white : null)),
                selected: sel,
                selectedColor: AppTheme.primaryTeal,
                onSelected: (_) => setState(() => _specialtyFilter = sp),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (!_canPublish) ...[
          _buildReadOnlyNotice(),
          const SizedBox(height: 14),
        ],
        ...filtered.map((pub) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${pub.academicRank.shortBadge} • ${pub.specialty}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primaryTeal),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(pub.contentType.label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(pub.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                    const SizedBox(height: 4),
                    Text(pub.summaryDescription, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${pub.authorName} • Fac ${pub.faculty}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.clinicalNavy, foregroundColor: Colors.white),
                          onPressed: () => _openPublicationViewer(pub),
                          child: Text(pub.contentType == TeacherContentType.mindmap ? 'Ouvrir Mindmap' : 'Consulter'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  /// Bandeau affiché aux comptes non habilités : consultation libre,
  /// publication verrouillée.
  Widget _buildReadOnlyNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF7C3AED)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Espace en lecture seule',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF6D28D9)),
                ),
                SizedBox(height: 3),
                Text(
                  'La publication de cours, fiches et examens est réservée aux enseignants HU dont le grade est vérifié '
                  '(Professeur, Maître de Conférences, Maître-Assistant, Assistant, Résident). '
                  'Pour être habilité, demandez la validation de votre grade à l\'administration Medsina.',
                  style: TextStyle(fontSize: 11.5, height: 1.35, color: Color(0xFF4C1D95)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // TAB 5 : Rémunération de l'enseignant (65 % auteurs / 35 % plateforme)
  Widget _buildEarningsTab() {
    if (_earningsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final settings = _earnings.settings;
    final canWithdraw = _earnings.availableBalance >= settings.minPayoutAmount;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SOLDE DISPONIBLE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 0.6),
                ),
                const SizedBox(height: 6),
                Text(
                  formatDzd(_earnings.availableBalance),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _earningsMetric('En rétention', formatDzd(_earnings.pendingBalance), settings.holdbackDays),
                    ),
                    Expanded(
                      child: _earningsMetric('Cumul généré', formatDzd(_earnings.lifetimeEarnings), null),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.primaryTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${settings.authorSharePct.toStringAsFixed(0)} % du revenu net est réparti entre les auteurs au prorata de l'usage réel "
                    "(${settings.platformSharePct.toStringAsFixed(0)} % Medsina). "
                    "Retraits à partir de ${formatDzd(settings.minPayoutAmount)}, disponibles après ${settings.holdbackDays} jours.",
                    style: const TextStyle(fontSize: 11, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: Text(
                canWithdraw
                    ? 'Demander un retrait'
                    : 'Retrait dès ${formatDzd(settings.minPayoutAmount)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.clinicalNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: canWithdraw ? _openPayoutSheet : null,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Historique des retraits', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 8),
          if (_earnings.payouts.isEmpty)
            Text(
              'Aucune demande de retrait pour le moment.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            ..._earnings.payouts.map(_buildPayoutRow),
          const SizedBox(height: 20),
          const Text('Détail par mois', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 8),
          if (_earnings.ledger.isEmpty)
            Text(
              'Aucun revenu calculé pour le moment. Les gains sont crédités à la clôture mensuelle.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            ..._earnings.ledger.map(_buildLedgerRow),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _earningsMetric(String label, String value, int? holdbackDays) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          holdbackDays == null ? label : '$label ($holdbackDays j)',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }

  Widget _buildPayoutRow(TeacherPayoutItem payout) {
    Color color;
    switch (payout.status) {
      case 'paid':
        color = const Color(0xFF10B981);
        break;
      case 'approved':
        color = const Color(0xFF0284C7);
        break;
      case 'rejected':
      case 'cancelled':
        color = const Color(0xFFEF4444);
        break;
      default:
        color = const Color(0xFFF59E0B);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.account_balance_wallet_rounded, color: color),
        title: Text(
          '${formatDzd(payout.amount)} • ${payout.methodLabel}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        subtitle: Text(
          '${_monthLabel(payout.requestedAt)}${payout.adminNote != null && payout.adminNote!.isNotEmpty ? ' • ${payout.adminNote}' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            payout.statusLabel,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildLedgerRow(TeacherLedgerEntry entry) {
    final available = entry.isAvailable;
    final color = available ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        dense: true,
        title: Text(
          _monthLabel(entry.periodMonth),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        subtitle: Text(
          '${entry.units.toStringAsFixed(1)} unités • ${available ? 'disponible' : 'en rétention'}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Text(
          formatDzd(entry.earnings),
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color),
        ),
      ),
    );
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _openPayoutSheet() async {
    final settings = _earnings.settings;
    final amountCtrl = TextEditingController(text: _earnings.availableBalance.toStringAsFixed(0));
    final holderCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    String method = 'ccp';
    String? error;
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Demande de retrait', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                'Solde disponible : ${formatDzd(_earnings.availableBalance)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Montant (DZD)',
                  helperText: 'Minimum ${formatDzd(settings.minPayoutAmount)}',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Mode de paiement', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'ccp', child: Text('CCP (Algérie Poste)')),
                  DropdownMenuItem(value: 'baridimob', child: Text('BaridiMob')),
                  DropdownMenuItem(value: 'virement', child: Text('Virement bancaire')),
                ],
                onChanged: (v) => setSheetState(() => method = v ?? 'ccp'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: holderCtrl,
                decoration: const InputDecoration(labelText: 'Titulaire du compte', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: accountCtrl,
                decoration: const InputDecoration(labelText: 'Numéro CCP / RIB / téléphone BaridiMob', isDense: true),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: busy
                      ? null
                      : () async {
                          final amount = double.tryParse(amountCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
                          setSheetState(() {
                            busy = true;
                            error = null;
                          });
                          final result = await TeacherEarningsService.requestPayout(
                            amount: amount,
                            method: method,
                            accountHolder: holderCtrl.text,
                            accountDetails: accountCtrl.text,
                            settings: settings,
                            availableBalance: _earnings.availableBalance,
                          );
                          if (!ctx.mounted) return;
                          if (result != null) {
                            setSheetState(() {
                              busy = false;
                              error = result;
                            });
                            return;
                          }
                          Navigator.pop(ctx);
                          await _loadAll();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demande de retrait envoyée. Elle sera traitée par l\'administration.'),
                              backgroundColor: AppTheme.primaryTeal,
                            ),
                          );
                        },
                  child: Text(busy ? 'Envoi…' : 'Envoyer la demande', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    amountCtrl.dispose();
    holderCtrl.dispose();
    accountCtrl.dispose();
  }

  void _openPublicationViewer(TeacherPublicationItem pub) {
    // Attribution du revenu : une ouverture réelle = 1 unité (dédupliquée 24 h).
    TeacherEarningsService.recordConsumption(
      contentType: 'publication',
      contentId: pub.id,
    );
    if (pub.contentType == TeacherContentType.mindmap) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WhiteboardListScreen()),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Text(pub.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 4),
            Text('${pub.authorName} (${pub.academicRank.label}) • ${pub.specialty}', style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w700)),
            const Divider(height: 24),
            if (pub.markdownBody.isNotEmpty) MarkdownBody(data: pub.markdownBody),
            if (pub.flashcards.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Flashcards FSRS incluses :', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 8),
              ...pub.flashcards.map((c) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('Q : ${c.front}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('R : ${c.back}', style: const TextStyle(fontSize: 12.5, color: AppTheme.primaryTeal)),
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  // TAB 2 : Liste & Passage des Examens EMD / Concours
  Widget _buildExamsListTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _exams.length,
      itemBuilder: (context, idx) {
        final exam = _exams[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(exam.categoryLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.14),
                    ),
                    Text('Code : ${exam.accessCode}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryTeal)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(exam.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                const SizedBox(height: 4),
                Text(
                  '${exam.authorName} (${exam.academicRank.shortBadge}) • ${exam.specialty} • ${exam.durationMinutes} min • ${exam.totalQuestionsCount} questions (Medsina: ${exam.medsinaQuestionIds.length}, Custom/QROC: ${exam.customQuestions.length})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Passer l\'Examen (QCM + QROC)', style: TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                    onPressed: () => _launchTeacherExamRunner(exam),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _launchTeacherExamRunner(TeacherExamModel exam) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _TeacherExamRunnerScreen(exam: exam)),
    );
  }

  // TAB 3 : Studio de Publication Prof
  Widget _buildPublishStudioTab() {
    final specialties = _modules.isNotEmpty
        ? _modules.map((m) => m.name).toSet().toList()
        : ['Cardiologie', 'Pneumologie', 'Neurologie', 'Pédiatrie', 'Gynécologie', 'Chirurgie'];
    if (!specialties.contains(_pubSpecialty)) _pubSpecialty = specialties.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.bentoCardDecoration(context, radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('STUDIO DE PUBLICATION ENSEIGNANT', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppTheme.primaryTeal)),
              const SizedBox(height: 12),
              // Grade vérifié par l'administration : non modifiable côté client.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 18, color: AppTheme.primaryTeal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedRank.label} — grade vérifié',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _pubSpecialty,
                decoration: const InputDecoration(labelText: 'Spécialité / Module', isDense: true),
                items: specialties.take(30).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _pubSpecialty = v ?? 'Cardiologie'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TeacherContentType>(
                initialValue: _selectedContentType,
                decoration: const InputDecoration(labelText: 'Type de Ressource', isDense: true),
                items: TeacherContentType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                onChanged: (v) => setState(() => _selectedContentType = v ?? TeacherContentType.course),
              ),
              const SizedBox(height: 10),
              TextField(controller: _pubTitleCtrl, decoration: const InputDecoration(labelText: 'Titre du Cours / Fiche / Mindmap', isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: _pubSummaryCtrl, decoration: const InputDecoration(labelText: 'Objectifs pédagogiques / Résumé court', isDense: true)),
              const SizedBox(height: 10),
              TextField(
                controller: _pubBodyCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Contenu complet (Markdown supporté)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedContentType == TeacherContentType.flashcards) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text('Ajouter une Flashcard (${_draftFlashcards.length})'),
                  onPressed: _addDraftFlashcardDialog,
                ),
                const SizedBox(height: 8),
              ],
              if (_selectedContentType == TeacherContentType.mindmap) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.hub_rounded),
                  label: const Text('Dessiner dans Medsina Whiteboard Studio'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WhiteboardListScreen())),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.publish_rounded),
                  label: const Text('Publier dans Medsina', style: TextStyle(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                  onPressed: _submitPublication,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addDraftFlashcardDialog() async {
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle Flashcard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: frontCtrl, decoration: const InputDecoration(labelText: 'Question (Recto)')),
            TextField(controller: backCtrl, decoration: const InputDecoration(labelText: 'Réponse (Verso)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (frontCtrl.text.isNotEmpty && backCtrl.text.isNotEmpty) {
                setState(() => _draftFlashcards.add(TeacherFlashcardPair(front: frontCtrl.text, back: backCtrl.text)));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPublication() async {
    if (!_canPublish) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication réservée aux enseignants dont le grade est vérifié.')),
      );
      return;
    }
    if (_pubTitleCtrl.text.trim().isEmpty) return;
    final user = context.read<AuthBloc>().state.user;
    final item = TeacherPublicationItem(
      id: 'pub_${DateTime.now().millisecondsSinceEpoch}',
      authorName: user?.fullName ?? 'Dr. Enseignant',
      academicRank: _selectedRank,
      specialty: _pubSpecialty,
      faculty: user?.faculty ?? 'Blida',
      contentType: _selectedContentType,
      title: _pubTitleCtrl.text.trim(),
      summaryDescription: _pubSummaryCtrl.text.trim(),
      markdownBody: _pubBodyCtrl.text.trim(),
      flashcards: List.from(_draftFlashcards),
      createdAt: DateTime.now(),
    );
    await TeacherWorkspaceService.publishItem(item);
    _pubTitleCtrl.clear();
    _pubSummaryCtrl.clear();
    _pubBodyCtrl.clear();
    _draftFlashcards.clear();
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication ajoutée avec succès !'), backgroundColor: AppTheme.primaryTeal),
      );
      _tabController.animateTo(0);
    }
  }

  // TAB 4 : Créateur d'Examens EMD & Concours (Hybride Medsina + Custom QCM/QROC)
  Widget _buildExamBuilderTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.bentoCardDecoration(context, radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LANCEUR D\'EXAMENS EMD & CONCOURS RÉSIDANAT', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppTheme.primaryTeal)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _examCategory,
                decoration: const InputDecoration(labelText: 'Type d\'Épreuve', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'emd_externat', child: Text('Examen EMD (Externat)')),
                  DropdownMenuItem(value: 'concours_residanat', child: Text('Concours Blanc de Résidanat')),
                  DropdownMenuItem(value: 'stage_evaluation', child: Text('Évaluation de Fin de Stage')),
                ],
                onChanged: (v) => setState(() => _examCategory = v ?? 'emd_externat'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _examTitleCtrl, decoration: const InputDecoration(labelText: 'Intitulé de l\'examen (ex: EMD Cardio 2027)', isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: _examDurationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Durée (minutes)', isDense: true)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.library_add_rounded, size: 17),
                      label: Text('Piocher Medsina (${_pickedMedsinaQcms.length})'),
                      onPressed: _openMedsinaQcmPicker,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_rounded, size: 17),
                      label: Text('Rédiger QCM/QROC (${_draftCustomQuestions.length})'),
                      onPressed: _openCustomQuestionComposer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text('Lancer & Publier l\'Examen', style: TextStyle(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.clinicalNavy, foregroundColor: Colors.white),
                  onPressed: _publishHybridExam,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openMedsinaQcmPicker() async {
    final firstMod = _modules.isNotEmpty ? _modules.first.id : 'Blida_CARDIOLOGIE';
    final qs = await TeacherWorkspaceService.fetchMedsinaBankQuestions(firstMod);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sélectionner des QCMs de la banque Medsina', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: qs.take(30).length,
                  itemBuilder: (c, i) {
                    final q = qs[i];
                    final sel = _pickedMedsinaQcms.any((p) => p.id == q.id);
                    return CheckboxListTile(
                      value: sel,
                      title: Text(q.questionText, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${q.courseName} • ${q.source}'),
                      onChanged: (v) {
                        setSheetState(() {
                          if (v == true) {
                            _pickedMedsinaQcms.add(q);
                          } else {
                            _pickedMedsinaQcms.removeWhere((p) => p.id == q.id);
                          }
                        });
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Valider (${_pickedMedsinaQcms.length} sélectionnées)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCustomQuestionComposer() async {
    CustomQuestionFormat format = CustomQuestionFormat.qroc;
    final textCtrl = TextEditingController();
    final refAnsCtrl = TextEditingController();
    final keywordsCtrl = TextEditingController();
    final explCtrl = TextEditingController();
    final optCtrls = List.generate(4, (_) => TextEditingController());
    final Set<int> correctIndices = {0};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Rédiger une Question Custom', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CustomQuestionFormat>(
                  initialValue: format,
                  items: CustomQuestionFormat.values.map((f) => DropdownMenuItem(value: f, child: Text(f.label))).toList(),
                  onChanged: (v) => setDlgState(() => format = v ?? CustomQuestionFormat.qroc),
                ),
                TextField(controller: textCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Énoncé de la question')),
                if (format == CustomQuestionFormat.qroc) ...[
                  TextField(controller: refAnsCtrl, decoration: const InputDecoration(labelText: 'Réponse attendue (QROC)')),
                  TextField(controller: keywordsCtrl, decoration: const InputDecoration(labelText: 'Mots-clés (séparés par virgule)')),
                ] else ...[
                  ...List.generate(4, (i) => Row(
                        children: [
                          Checkbox(
                            value: correctIndices.contains(i),
                            onChanged: (v) => setDlgState(() {
                              if (v == true) {
                                correctIndices.add(i);
                              } else {
                                correctIndices.remove(i);
                              }
                            }),
                          ),
                          Expanded(child: TextField(controller: optCtrls[i], decoration: InputDecoration(labelText: 'Proposition ${String.fromCharCode(65 + i)}'))),
                        ],
                      )),
                ],
                TextField(controller: explCtrl, decoration: const InputDecoration(labelText: 'Explication pédagogique')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (textCtrl.text.trim().isEmpty) return;
                setState(() {
                  _draftCustomQuestions.add(CustomExamQuestion(
                    id: 'cq_${DateTime.now().millisecondsSinceEpoch}',
                    format: format,
                    questionText: textCtrl.text.trim(),
                    options: format == CustomQuestionFormat.qroc
                        ? const []
                        : optCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
                    correctOptionIndices: correctIndices.toList(),
                    qrocReferenceAnswer: refAnsCtrl.text.trim(),
                    qrocExpectedKeywords: keywordsCtrl.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                    explanation: explCtrl.text.trim(),
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Ajouter à l\'Examen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishHybridExam() async {
    if (!_canPublish) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Création d\'examen réservée aux enseignants dont le grade est vérifié.')),
      );
      return;
    }
    if (_examTitleCtrl.text.trim().isEmpty ||
        (_pickedMedsinaQcms.isEmpty && _draftCustomQuestions.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez un titre et au moins 1 question (Medsina ou Custom).')),
      );
      return;
    }
    final user = context.read<AuthBloc>().state.user;
    final code = TeacherWorkspaceService.generateExamAccessCode(_examSpecialty);
    final exam = TeacherExamModel(
      id: 'exam_${DateTime.now().millisecondsSinceEpoch}',
      accessCode: code,
      authorName: user?.fullName ?? 'Dr. Enseignant',
      academicRank: _selectedRank,
      specialty: _examSpecialty,
      faculty: user?.faculty ?? 'Blida',
      examCategory: _examCategory,
      title: _examTitleCtrl.text.trim(),
      durationMinutes: int.tryParse(_examDurationCtrl.text) ?? 45,
      medsinaQuestionIds: _pickedMedsinaQcms.map((q) => q.id).toList(),
      customQuestions: List.from(_draftCustomQuestions),
      createdAt: DateTime.now(),
    );
    await TeacherWorkspaceService.publishExam(exam);
    _examTitleCtrl.clear();
    _pickedMedsinaQcms.clear();
    _draftCustomQuestions.clear();
    await _loadAll();
    if (mounted) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Examen publié ! Code d\'accès copié : $code'), backgroundColor: AppTheme.primaryTeal),
      );
      _tabController.animateTo(1);
    }
  }
}

class _TeacherExamRunnerScreen extends StatefulWidget {
  final TeacherExamModel exam;
  const _TeacherExamRunnerScreen({required this.exam});

  @override
  State<_TeacherExamRunnerScreen> createState() => _TeacherExamRunnerScreenState();
}

class _TeacherExamRunnerScreenState extends State<_TeacherExamRunnerScreen> {
  final Map<String, Set<int>> _mcqAnswers = {};
  final Map<String, TextEditingController> _qrocCtrls = {};
  bool _submitted = false;
  double _scoreOutOf20 = 0.0;

  @override
  void dispose() {
    for (final c in _qrocCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    // Attribution du revenu : un passage d'examen = 5 unités (une seule fois).
    TeacherEarningsService.recordConsumption(
      contentType: 'exam',
      contentId: widget.exam.id,
      units: 5,
    );
    final questions = widget.exam.customQuestions;
    if (questions.isEmpty) {
      setState(() {
        _submitted = true;
        _scoreOutOf20 = 20.0;
      });
      return;
    }
    double earned = 0.0;
    for (final q in questions) {
      if (q.format == CustomQuestionFormat.qroc) {
        final text = _qrocCtrls[q.id]?.text ?? '';
        earned += q.evaluateQrocAnswer(text);
      } else {
        final chosen = _mcqAnswers[q.id] ?? {};
        final expected = q.correctOptionIndices.toSet();
        if (chosen.length == expected.length && chosen.every(expected.contains)) {
          earned += 1.0;
        }
      }
    }
    setState(() {
      _submitted = true;
      _scoreOutOf20 = (earned / questions.length) * 20.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exam.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_submitted)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: AppTheme.heroNavyDecoration(radius: 18),
              child: Column(
                children: [
                  const Text('NOTE CORRIGÉE AUTOMATIQUEMENT', style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('${_scoreOutOf20.toStringAsFixed(2)} / 20', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ...widget.exam.customQuestions.asMap().entries.map((entry) {
            final idx = entry.key;
            final q = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Question ${idx + 1} • ${q.format.label}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppTheme.primaryTeal)),
                    const SizedBox(height: 6),
                    Text(q.questionText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 10),
                    if (q.format == CustomQuestionFormat.qroc) ...[
                      TextField(
                        controller: _qrocCtrls.putIfAbsent(q.id, () => TextEditingController()),
                        enabled: !_submitted,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Saisissez votre réponse courte (QROC)...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_submitted) ...[
                        const SizedBox(height: 8),
                        Text('✓ Réponse type : ${q.qrocReferenceAnswer}', style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w800, fontSize: 12.5)),
                      ],
                    ] else ...[
                      ...q.options.asMap().entries.map((opt) {
                        final selectedSet = _mcqAnswers.putIfAbsent(q.id, () => <int>{});
                        final isSel = selectedSet.contains(opt.key);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: isSel,
                          title: Text('${String.fromCharCode(65 + opt.key)}. ${opt.value}', style: const TextStyle(fontSize: 13)),
                          onChanged: _submitted
                              ? null
                              : (v) => setState(() {
                                    if (v == true) {
                                      selectedSet.add(opt.key);
                                    } else {
                                      selectedSet.remove(opt.key);
                                    }
                                  }),
                        );
                      }),
                    ],
                    if (_submitted && q.explanation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('💡 ${q.explanation}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ),
            );
          }),
          if (!_submitted)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _submit,
              child: const Text('Soumettre ma Copie & Corriger', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );
  }
}
