import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../ai_assistant/presentation/clinical_copilot_sheet.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../subscription/presentation/subscription_paywall_screen.dart';
import '../bloc/clinical_bloc.dart';
import '../bloc/clinical_event.dart';
import '../bloc/clinical_state.dart';
import '../models/cat_protocol_model.dart';
import '../models/clinical_calculator_model.dart';

class ClinicalScreen extends StatefulWidget {
  const ClinicalScreen({super.key});

  @override
  State<ClinicalScreen> createState() => _ClinicalScreenState();
}

class _ClinicalScreenState extends State<ClinicalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<ClinicalBloc>().add(LoadClinicalDataEvent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: const Text('Copilote Clinique IA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        onPressed: () => ClinicalCopilotSheet.show(context),
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryTeal,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppTheme.primaryTeal,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.emergency_rounded),
                  text: 'Protocoles & CAT',
                ),
                Tab(
                  icon: Icon(Icons.calculate_rounded),
                  text: 'Scores Cliniques',
                ),
                Tab(
                  icon: Icon(Icons.medication_liquid_rounded),
                  text: 'Urgences & DCI Algérie',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ProtocolsTab(),
                _CalculatorsTab(),
                _EmergencyDrugsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtocolsTab extends StatelessWidget {
  const _ProtocolsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClinicalBloc, ClinicalState>(
      builder: (context, state) {
        if (state.status == ClinicalStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Search & Filter header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher une urgence, protocole, scorpion, rage...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: state.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => context.read<ClinicalBloc>().add(const SearchProtocolsEvent('')),
                            )
                          : null,
                    ),
                    onChanged: (val) => context.read<ClinicalBloc>().add(SearchProtocolsEvent(val)),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.availableSpecialties.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final spec = state.availableSpecialties[index];
                        final isSelected = spec == state.selectedSpecialty;
                        return ChoiceChip(
                          label: Text(spec),
                          selected: isSelected,
                          onSelected: (_) => context.read<ClinicalBloc>().add(FilterSpecialtyEvent(spec)),
                          selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.18),
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.primaryDarkTeal : null,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Protocols List
            Expanded(
              child: state.filteredProtocols.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('Aucun protocole pour "${state.searchQuery}"', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.filteredProtocols.length,
                      itemBuilder: (context, index) {
                        final protocol = state.filteredProtocols[index];
                        return _ProtocolCard(protocol: protocol);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ProtocolCard extends StatefulWidget {
  final ClinicalProtocol protocol;
  const _ProtocolCard({required this.protocol});

  @override
  State<_ProtocolCard> createState() => _ProtocolCardState();
}

class _ProtocolCardState extends State<_ProtocolCard> {
  bool _expanded = false;

  Color _getUrgencyColor(String urgency) {
    if (urgency.contains('Vitale')) return const Color(0xFFDC2626);
    if (urgency.contains('Relative')) return const Color(0xFFD97706);
    return const Color(0xFF2563EB);
  }

  void _showPaywallPrompt(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Contenu Clinique Réservé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
              );
            },
            child: const Text('Voir les Formules ➔'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.protocol;
    final urgColor = _getUrgencyColor(p.urgencyLevel);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final authState = context.watch<AuthBloc>().state;
    final user = authState.user;
    final isExpired = user?.isSubscriptionActive == false;
    final isFree = user?.tier == SubscriptionTier.free;
    final isPreviewCAT = p.id.contains('scorpion') || p.id.contains('acr');
    final isLocked = isExpired || (isFree && !isPreviewCAT);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: urgColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isLocked) {
            final reason = isExpired
                ? 'Votre abonnement a expiré. Veuillez renouveler votre formule pour accéder aux Conduites à Tenir cliniques et protocoles d\'urgence.'
                : 'La CAT "${p.title}" fait partie du Pass Clinique Pro ou Medsina All-Access. Votre Pass Découverte donne accès aux 2 premières CAT d\'urgence (Envenimation scorpionique et ACR).';
            _showPaywallPrompt(context, reason);
            return;
          }
          setState(() => _expanded = !_expanded);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.urgencyLevel.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: urgColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.specialty,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ),
                  if (isLocked) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 11, color: Color(0xFFD97706)),
                          SizedBox(width: 4),
                          Text('Verrouillé', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    isLocked
                        ? Icons.lock_outline_rounded
                        : (_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
                    color: isLocked ? const Color(0xFFD97706) : null,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                p.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),

              // Definition
              Text(
                p.definition,
                style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, height: 1.3),
              ),

              // Red Flags Preview
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: p.redFlags.take(2).map((rf) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        rf,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )).toList(),
              ),

              // Expanded Details
              if (_expanded) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),

                // All Red Flags
                const Text('🚩 Signes d\'Alarme & Critères de Gravité :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFDC2626))),
                const SizedBox(height: 6),
                ...p.redFlags.map((rf) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                      Expanded(child: Text(rf, style: const TextStyle(fontSize: 12, height: 1.3))),
                    ],
                  ),
                )),
                const SizedBox(height: 14),

                // Clinical Steps
                const Text('📋 Étapes de la Prise en Charge :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryDarkTeal)),
                const SizedBox(height: 8),
                ...p.steps.map((step) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF2563EB))),
                      const SizedBox(height: 4),
                      Text(step.content, style: const TextStyle(fontSize: 12, height: 1.35)),
                      if (step.bulletPoints.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...step.bulletPoints.map((bp) => Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('› ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                              Expanded(child: Text(bp, style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800, height: 1.3))),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),
                )),

                // Essential Treatments
                const Text('💊 Traitements Immédiats :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF16A34A))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: p.treatments.map((t) => Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: const Color(0xFFDCFCE7),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    label: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  )).toList(),
                ),

                const SizedBox(height: 12),
                Text(
                  '📚 Source / Consensus : ${p.references}',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('Approfondir avec le Copilote Clinique Gemini ✨', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    onPressed: () => ClinicalCopilotSheet.show(context, initialSituation: '${p.title} (${p.urgencyLevel}) - ${p.definition}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalculatorsTab extends StatefulWidget {
  const _CalculatorsTab();

  @override
  State<_CalculatorsTab> createState() => _CalculatorsTabState();
}

class _CalculatorsTabState extends State<_CalculatorsTab> {
  // Glasgow State
  int _gcsEye = 4;
  int _gcsVerbal = 5;
  int _gcsMotor = 6;

  // Wells PE State
  bool _wellsDvt = false;
  bool _wellsAltDiagnosis = true;
  bool _wellsHr = false;
  bool _wellsImmob = false;
  bool _wellsHistory = false;
  bool _wellsHemo = false;
  bool _wellsCancer = false;

  // Cockcroft State
  int _age = 65;
  double _weight = 70;
  double _creatinine = 90;
  bool _isFemale = false;

  // qSOFA State
  bool _qsofaRr = true;
  bool _qsofaGcs = false;
  bool _qsofaBp = true;

  // CHA2DS2-VASc State
  bool _chaChf = false;
  bool _chaHta = true;
  int _chaAge = 68;
  bool _chaDiab = false;
  bool _chaStroke = false;
  bool _chaVasc = false;
  bool _chaFemale = false;

  // Apgar State
  int _apgarHr = 2;
  int _apgarResp = 2;
  int _apgarTone = 2;
  int _apgarReflex = 2;
  int _apgarColor = 1;

  final Set<String> _expandedCalculators = {'qsofa'};

  void _toggleCalculator(String id) {
    setState(() {
      if (_expandedCalculators.contains(id)) {
        _expandedCalculators.remove(id);
      } else {
        _expandedCalculators.add(id);
      }
    });
  }

  Widget _buildCalculatorCard({
    required String id,
    required IconData icon,
    required Color iconColor,
    required String title,
    required CalculatorResult result,
    required Widget child,
  }) {
    final isExpanded = _expandedCalculators.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isExpanded ? iconColor.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleCalculator(id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.interpretation,
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildScorePill('${result.value} ${result.unit}'.trim(), result.severityColor),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  child,
                  const SizedBox(height: 14),
                  _buildResultBox(result),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                '6 Calculateurs & Scores Validés',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                ),
                icon: Icon(
                  _expandedCalculators.isEmpty ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
                  size: 16,
                  color: AppTheme.primaryTeal,
                ),
                label: Text(
                  _expandedCalculators.isEmpty ? 'Déplier tout' : 'Replier tout',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                ),
                onPressed: () {
                  setState(() {
                    if (_expandedCalculators.isEmpty) {
                      _expandedCalculators.addAll(['qsofa', 'glasgow', 'wells', 'cha2ds2', 'cockcroft', 'apgar']);
                    } else {
                      _expandedCalculators.clear();
                    }
                  });
                },
              ),
            ],
          ),
        ),
        _buildQsofaCard(),
        _buildGlasgowCard(),
        _buildWellsPeCard(),
        _buildCha2ds2VascCard(),
        _buildCockcroftCard(),
        _buildApgarCard(),
      ],
    );
  }

  Widget _buildQsofaCard() {
    final res = ClinicalCalculators.calculateQsofa(
      respRate22OrMore: _qsofaRr,
      alteredMentation: _qsofaGcs,
      sysBp100OrLess: _qsofaBp,
    );

    return _buildCalculatorCard(
      id: 'qsofa',
      icon: Icons.warning_rounded,
      iconColor: const Color(0xFFDC2626),
      title: 'Score qSOFA — Alerte Sepsis UMC',
      result: res,
      child: Column(
        children: [
          CheckboxListTile(
            dense: true,
            value: _qsofaRr,
            title: const Text('Fréquence respiratoire ≥ 22 /min (+1 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _qsofaRr = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _qsofaGcs,
            title: const Text('Confusion ou altération de conscience / Glasgow < 15 (+1 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _qsofaGcs = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _qsofaBp,
            title: const Text('Pression Artérielle Systolique ≤ 100 mmHg (+1 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _qsofaBp = v ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildGlasgowCard() {
    final res = ClinicalCalculators.calculateGlasgow(eye: _gcsEye, verbal: _gcsVerbal, motor: _gcsMotor);

    return _buildCalculatorCard(
      id: 'glasgow',
      icon: Icons.psychology_rounded,
      iconColor: AppTheme.primaryTeal,
      title: 'Score de Glasgow (GCS) — Conscience & Coma',
      result: res,
      child: Column(
        children: [
          _buildDropdownRow('Ouverture des yeux (Y) :', _gcsEye, {
            4: '4 - Spontanée',
            3: '3 - Au bruit / ordre',
            2: '2 - À la douleur',
            1: '1 - Nulle',
          }, (val) => setState(() => _gcsEye = val!)),
          const SizedBox(height: 8),
          _buildDropdownRow('Réponse verbale (V) :', _gcsVerbal, {
            5: '5 - Orientée',
            4: '4 - Confuse',
            3: '3 - Inappropriée',
            2: '2 - Incompréhensible',
            1: '1 - Nulle',
          }, (val) => setState(() => _gcsVerbal = val!)),
          const SizedBox(height: 8),
          _buildDropdownRow('Réponse motrice (M) :', _gcsMotor, {
            6: '6 - Aux ordres',
            5: '5 - Orientée à la douleur',
            4: '4 - Retrait / Évitement',
            3: '3 - Décortication (Flexion)',
            2: '2 - Décérébration (Extension)',
            1: '1 - Nulle',
          }, (val) => setState(() => _gcsMotor = val!)),
        ],
      ),
    );
  }

  Widget _buildWellsPeCard() {
    final res = ClinicalCalculators.calculateWellsPE(
      signsDvt: _wellsDvt,
      altDiagnosisLessLikely: _wellsAltDiagnosis,
      heartRateOver100: _wellsHr,
      immobilizationOrSurgery: _wellsImmob,
      previousDvtPe: _wellsHistory,
      hemoptysis: _wellsHemo,
      activeCancer: _wellsCancer,
    );

    return _buildCalculatorCard(
      id: 'wells',
      icon: Icons.air_rounded,
      iconColor: AppTheme.accentCyan,
      title: 'Score de Wells — Embolie Pulmonaire',
      result: res,
      child: Column(
        children: [
          CheckboxListTile(
            dense: true,
            value: _wellsDvt,
            title: const Text('Signes cliniques de TVP (+3 pts)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _wellsDvt = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _wellsAltDiagnosis,
            title: const Text('Diagnostic alternatif moins probable qu\'une EP (+3 pts)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _wellsAltDiagnosis = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _wellsHr,
            title: const Text('Fréquence cardiaque > 100 bpm (+1.5 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _wellsHr = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _wellsImmob,
            title: const Text('Immobilisation >= 3j ou chirurgie < 4 semaines (+1.5 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _wellsImmob = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _wellsHistory,
            title: const Text('Antécédent personnel de TVP ou EP (+1.5 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _wellsHistory = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _wellsHemo,
            title: const Text('Hémoptysie (+1 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _wellsHemo = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _wellsCancer,
            title: const Text('Cancer actif ou sous traitement < 6 mois (+1 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _wellsCancer = v ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildCha2ds2VascCard() {
    final res = ClinicalCalculators.calculateCha2ds2Vasc(
      congestiveHeartFailure: _chaChf,
      hypertension: _chaHta,
      age: _chaAge,
      diabetes: _chaDiab,
      strokeTiaThromboembolism: _chaStroke,
      vascularDisease: _chaVasc,
      isFemale: _chaFemale,
    );

    return _buildCalculatorCard(
      id: 'cha2ds2',
      icon: Icons.favorite_rounded,
      iconColor: const Color(0xFFE11D48),
      title: 'CHA₂DS₂-VASc — Risque AVC / Fibrillation Atriale',
      result: res,
      child: Column(
        children: [
          _buildDropdownRow('Tranche d\'âge :', _chaAge, {
            60: '< 65 ans (0 pt)',
            68: '65 – 74 ans (+1 pt)',
            78: '≥ 75 ans (+2 pts)',
          }, (v) => setState(() => _chaAge = v!)),
          const SizedBox(height: 8),
          CheckboxListTile(
            dense: true,
            value: _chaHta,
            title: const Text('Hypertension Artérielle (+1 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _chaHta = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _chaChf,
            title: const Text('Insuffisance Cardiaque congestive (+1 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _chaChf = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _chaDiab,
            title: const Text('Diabète (+1 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _chaDiab = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _chaStroke,
            title: const Text('Antécédent d\'AVC / AIT / Thrombo-embolie (+2 pts)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _chaStroke = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _chaVasc,
            title: const Text('Maladie Vasculaire (IDM, artériopathie périphérique) (+1 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _chaVasc = v ?? false),
          ),
          CheckboxListTile(
            dense: true,
            value: _chaFemale,
            title: const Text('Sexe Féminin (+1 pt)', style: TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() => _chaFemale = v ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildCockcroftCard() {
    final res = ClinicalCalculators.calculateCockcroft(
      age: _age,
      weightKg: _weight,
      creatinineUmolL: _creatinine,
      isFemale: _isFemale,
    );

    return _buildCalculatorCard(
      id: 'cockcroft',
      icon: Icons.water_drop_rounded,
      iconColor: Colors.blueAccent,
      title: 'Clairance Cockcroft & Gault — Fonction Rénale',
      result: res,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _age.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Âge (ans)'),
                  onChanged: (v) => setState(() => _age = int.tryParse(v) ?? _age),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _weight.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Poids (kg)'),
                  onChanged: (v) => setState(() => _weight = double.tryParse(v) ?? _weight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _creatinine.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Créatinine (µmol/L)'),
                  onChanged: (v) => setState(() => _creatinine = double.tryParse(v) ?? _creatinine),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<bool>(
                  initialValue: _isFemale,
                  decoration: const InputDecoration(labelText: 'Sexe'),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('Homme')),
                    DropdownMenuItem(value: true, child: Text('Femme')),
                  ],
                  onChanged: (v) => setState(() => _isFemale = v ?? false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApgarCard() {
    final res = ClinicalCalculators.calculateApgar(
      heartRate: _apgarHr,
      breathing: _apgarResp,
      muscleTone: _apgarTone,
      reflex: _apgarReflex,
      skinColor: _apgarColor,
    );

    return _buildCalculatorCard(
      id: 'apgar',
      icon: Icons.child_care_rounded,
      iconColor: const Color(0xFFEC4899),
      title: 'Score d\'Apgar (Nouveau-né)',
      result: res,
      child: Column(
        children: [
          _buildDropdownRow('Fréquence cardiaque :', _apgarHr, {
            2: '2 - > 100 bpm',
            1: '1 - < 100 bpm',
            0: '0 - Absente',
          }, (v) => setState(() => _apgarHr = v!)),
          const SizedBox(height: 8),
          _buildDropdownRow('Respiration / Cri :', _apgarResp, {
            2: '2 - Vigoureuse, cri franc',
            1: '1 - Lente, irrégulière',
            0: '0 - Absente (apnée)',
          }, (v) => setState(() => _apgarResp = v!)),
          const SizedBox(height: 8),
          _buildDropdownRow('Tonus musculaire :', _apgarTone, {
            2: '2 - Mouvements actifs, quadri-flexion',
            1: '1 - Légère flexion des extrémités',
            0: '0 - Flasque',
          }, (v) => setState(() => _apgarTone = v!)),
          const SizedBox(height: 8),
          _buildDropdownRow('Réactivité aux stimuli :', _apgarReflex, {
            2: '2 - Vive (cris, toux, éternuement)',
            1: '1 - Faible (grimace)',
            0: '0 - Nulle',
          }, (v) => setState(() => _apgarReflex = v!)),
          const SizedBox(height: 8),
          _buildDropdownRow('Coloration cutanée :', _apgarColor, {
            2: '2 - Totalement rose',
            1: '1 - Corps rose, extrémités bleues',
            0: '0 - Cyanose ou pâleur globale',
          }, (v) => setState(() => _apgarColor = v!)),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, int value, Map<int, String> options, ValueChanged<int?> onChanged) {
    return Row(
      children: [
        SizedBox(width: 160, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Expanded(
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: options.entries
                .map((e) => DropdownMenuItem<int>(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildScorePill(String text, String colorName) {
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF334155);

    if (colorName == 'green') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
    } else if (colorName == 'amber') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (colorName == 'red') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: fg)),
    );
  }

  Widget _buildResultBox(CalculatorResult res) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(res.interpretation, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryDarkTeal)),
          const SizedBox(height: 4),
          Text(res.recommendation, style: const TextStyle(fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }
}

class EmergencyDrugItem {
  final String dci;
  final String brand;
  final String category;
  final String route;
  final String indication;
  final String dose;
  final String alert;

  const EmergencyDrugItem({
    required this.dci,
    required this.brand,
    required this.category,
    required this.route,
    required this.indication,
    required this.dose,
    required this.alert,
  });
}

class _EmergencyDrugsTab extends StatefulWidget {
  const _EmergencyDrugsTab();

  @override
  State<_EmergencyDrugsTab> createState() => _EmergencyDrugsTabState();
}

class _EmergencyDrugsTabState extends State<_EmergencyDrugsTab> {
  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  bool _triageExpanded = false;

  final List<String> _categories = [
    'Tous',
    'Cardio / ACR / Choc',
    'Respiratoire',
    'Neurologie / Sédation',
    'Infectiologie',
    'Antidotes & Sérums',
    'Antalgiques',
    'Hémostase & Anticoagulants',
    'Métabolisme & Endocrinologie',
  ];

  static const List<EmergencyDrugItem> _allDrugs = [
    EmergencyDrugItem(
      dci: 'Adrénaline',
      brand: 'Adrénaline Aguettant / Saidal',
      category: 'Cardio / ACR / Choc',
      route: 'IM / IVD',
      indication: 'Choc anaphylactique & Arrêt Cardiorespiratoire (ACR)',
      dose: '• Anaphylaxie : 0,5 mg IM (face antérolatérale de la cuisse)\n• Arrêt Cardiaque : 1 mg IVD toutes les 3-5 min\n• Enfant : 0,01 mg/kg IM (max 0,3 mg)',
      alert: 'Ne jamais injecter 1 mg IV directe en dehors de l\'arrêt cardiaque (risque de FV létale ou crise hypertensive sévère).',
    ),
    EmergencyDrugItem(
      dci: 'Noradrénaline',
      brand: 'Lévophed / Noradrénaline Saidal',
      category: 'Cardio / ACR / Choc',
      route: 'Perfusion IV (PSE)',
      indication: 'Choc septique, choc vasoplégique résistant au remplissage',
      dose: '• 0,1 à 1 µg/kg/min au PSE sur VVC (ou VVP de gros calibre en attente)\n• Objectif : PAM ≥ 65 mmHg',
      alert: 'Risque d\'ischémie distale sévère et de nécrose cutanée majeure en cas d\'extravasation veineuse.',
    ),
    EmergencyDrugItem(
      dci: 'Sérum Antiscorpionique (SAS)',
      brand: 'Institut Pasteur d\'Algérie (IPA)',
      category: 'Antidotes & Sérums',
      route: 'IVD lente / Perfusion',
      indication: 'Envenimation scorpionique Stades 2 et 3 (Guide MSPRH Algérie)',
      dose: '• 1 à 2 ampoules en IV directe lente (ou perfusion dans 50 mL NaCl 0,9% en 15 min)\n• Réévaluation à H2 : répéter 1 ampoule si persistance des signes systémiques',
      alert: 'Efficacité maximale dans les 2 premières heures après la piqûre. Inutile au Stade 1 (douleur locale isolée).',
    ),
    EmergencyDrugItem(
      dci: 'Amiodarone',
      brand: 'Cordarone / Saidal',
      category: 'Cardio / ACR / Choc',
      route: 'IVD / Perfusion',
      indication: 'Fibrillation / Tachycardie Ventriculaire sans pouls (ACR), TACFA instable',
      dose: '• ACR : 300 mg dans 20-30 mL G5% IVD après le 3e choc électrique, puis 150 mg après le 5e choc\n• TACFA : 5 mg/kg dans 250 mL G5% sur 20-60 min',
      alert: 'Toujours diluer dans du Sérum Glucosé 5% (G5%), jamais dans du NaCl 0,9% (précipitation immédiate).',
    ),
    EmergencyDrugItem(
      dci: 'Furosémide',
      brand: 'Lasilix / Saidal',
      category: 'Cardio / ACR / Choc',
      route: 'IVD lente',
      indication: 'Œdème Aigu du Poumon (OAP cardiogénique), surcharge volémique',
      dose: '• 40 à 80 mg IV directe lente (1 à 2 ampoules de 20 mg ou 1 ampoule de 40 mg)\n• Si insuffisance rénale : jusqu\'à 160-250 mg IV',
      alert: 'Contre-indiqué formellement si PAS < 90 mmHg (hypovolémie/choc). Surveiller kaliémie et diurèse horaire.',
    ),
    EmergencyDrugItem(
      dci: 'Ceftriaxone',
      brand: 'Rocéphine / Saftriaxone Saidal',
      category: 'Infectiologie',
      route: 'Perfusion IV',
      indication: 'Méningites purulentes, purpura fulminans, pneumopathies graves, choc septique',
      dose: '• Sepsis général : 2 g/j en perfusion IV de 30 min\n• Suspicion méningite purulente : 100 mg/kg/j IV (max 4 g/j), injecter immédiatement',
      alert: 'Céphalosporine de 3e génération de référence dans les UMC algériennes.',
    ),
    EmergencyDrugItem(
      dci: 'Méthylprednisolone',
      brand: 'Solumédrol / Saidal',
      category: 'Respiratoire',
      route: 'IVD / IM',
      indication: 'Crise d\'asthme sévère / AAG, laryngite aiguë sous-glottique, anaphylaxie',
      dose: '• Adulte : 1 à 2 mg/kg IV (soit 80 à 120 mg IV)\n• Enfant : 1 à 2 mg/kg IV ou IM',
      alert: 'Délai d\'action anti-inflammatoire de 4 à 6 heures. Ne remplace pas les bronchodilatateurs inhalés d\'urgence.',
    ),
    EmergencyDrugItem(
      dci: 'Salbutamol',
      brand: 'Ventoline / Saidal',
      category: 'Respiratoire',
      route: 'Nébulisation / IV',
      indication: 'Asthme Aigu Grave (AAG), BPCO décompensée, Hyperkaliémie menaçante',
      dose: '• AAG : 5 mg dans 4 mL sérum physiologique sous 6-8 L/min d\'O2, renouvelable toutes les 20 min\n• Hyperkaliémie : 10 à 20 mg en nébulisation',
      alert: 'Surveiller tachycardie, tremblements et hypokaliémie.',
    ),
    EmergencyDrugItem(
      dci: 'Diazépam',
      brand: 'Valium / Saidal',
      category: 'Neurologie / Sédation',
      route: 'IVD lente / Intra-rectal',
      indication: 'État de mal convulsif, crise convulsive fébrile, agitation sévère',
      dose: '• Adulte : 10 mg IV lente (1 ampoule) en 2 min, répéter une fois à 5-10 min si persistance\n• Enfant : 0,5 mg/kg en intra-rectal (canule)',
      alert: 'Risque d\'apnée et de dépression respiratoire : matériel de ventilation (Ambu/O2) obligatoire à portée de main.',
    ),
    EmergencyDrugItem(
      dci: 'Morphine (Sulfate de Morphine)',
      brand: 'Morphine Aguettant / Saidal',
      category: 'Antalgiques',
      route: 'IV titration',
      indication: 'Douleur aiguë intense (EVA ≥ 7), Syndrome Coronarien Aigu, OAP cardiogénique',
      dose: '• Titration IV : Bolus initial 2 à 3 mg IVD, puis 1 à 2 mg toutes les 5 minutes jusqu\'à EVA < 4\n• Antidote obligatoire à disposition : Naloxone (Narcan)',
      alert: 'Surveiller FR (FR < 10 = bradypnée toxique), sédation (score de Rudkin) et SpO2.',
    ),
    EmergencyDrugItem(
      dci: 'Enoxaparine',
      brand: 'Lovenox / Saidal',
      category: 'Hémostase & Anticoagulants',
      route: 'SC / Bolus IV',
      indication: 'Syndrome Coronarien Aigu (SCA), Embolie Pulmonaire, TVP',
      dose: '• Curatif : 100 UI/kg (soit 1 mg/kg) SC toutes les 12 heures\n• Bolus IV (SCA ST+ < 75 ans) : 3 000 UI IVD suivi de 1 mg/kg SC',
      alert: 'Adapter posologie si clairance créatinine < 30 mL/min (contre-indication relative, privilégier HNF).',
    ),
    EmergencyDrugItem(
      dci: 'Acide Tranexamique',
      brand: 'Exacyl / Saidal',
      category: 'Hémostase & Anticoagulants',
      route: 'Perfusion IV',
      indication: 'Hémorragie du post-partum, traumatisme grave avec choc hémorragique (CRASH-2)',
      dose: '• 1 g IV dans 100 mL NaCl 0,9% en 10 minutes, puis 1 g en perfusion continue sur 8 heures\n• À injecter impérativement dans les 3 premières heures suivant le saignement',
      alert: 'Efficacité nulle ou délétère si administré après 3 heures du traumatisme.',
    ),
    EmergencyDrugItem(
      dci: 'Insuline Rapide',
      brand: 'Actrapid / Umuline Rapide',
      category: 'Métabolisme & Endocrinologie',
      route: 'IV continu (PSE)',
      indication: 'Acidocétose diabétique, coma hyperosmolaire, hyperkaliémie sévère',
      dose: '• Acidocétose : 0,1 UI/kg/h au PSE après réhydratation par NaCl 0,9%\n• Hyperkaliémie : 10 UI dans 500 mL G10% en 30 min',
      alert: 'Ne jamais baisser la glycémie de plus de 0,5 à 1 g/L par heure. Surveiller la kaliémie en continu.',
    ),
    EmergencyDrugItem(
      dci: 'Gluconate de Calcium',
      brand: 'Gluconate de Calcium Saidal 10%',
      category: 'Métabolisme & Endocrinologie',
      route: 'IVD lente (5-10 min)',
      indication: 'Hyperkaliémie sévère (≥ 6,5 mmol/L ou anomalies ECG : ondes T pointues / élargissement QRS)',
      dose: '• 1 ampoule de 10 mL à 10% IV directe lente sur 5 minutes sous scope ECG\n• Renouvelable à 5-10 min si persistance des signes ECG',
      alert: 'Ne fait pas baisser le potassium ! Stabilise la membrane myocardique contre la FV. Contre-indiqué si digitaliques.',
    ),
    EmergencyDrugItem(
      dci: 'Atropine',
      brand: 'Sulfate d\'Atropine Saidal',
      category: 'Cardio / ACR / Choc',
      route: 'IVD',
      indication: 'Bradycardie sinusale symptomatique sévère (FC < 40, hypotension), intoxication organophosphorés',
      dose: '• Bradycardie : 0,5 mg à 1 mg IVD toutes les 3-5 min (dose max 3 mg)\n• Intoxication organophosphorés : 2 à 5 mg IVD toutes les 10-15 min jusqu\'à atropinisation',
      alert: 'Inefficace sur les blocs auriculo-ventriculaires de haut degré (BAV III, Mobitz II à QRS large).',
    ),
    EmergencyDrugItem(
      dci: 'Trinitrine / Dinitrate d\'Isosorbide',
      brand: 'Risordan / Saidal / Lenitral',
      category: 'Cardio / ACR / Choc',
      route: 'Sublingual / PSE',
      indication: 'Syndrome Coronarien Aigu (SCA), Poussée hypertensive avec OAP',
      dose: '• Sublingual : 1 bouffée de spray sous la langue toutes les 5 min (max 3 bouffées)\n• PSE : 1 à 3 mg/h au pousse-seringue électrique',
      alert: 'Contre-indiqué formellement si PAS < 90 mmHg, infarctus du ventricule droit ou prise de Viagra/Cialis < 48h.',
    ),
    EmergencyDrugItem(
      dci: 'Vaccin Antirabique + Sérum',
      brand: 'Rabipur / Sérum Antirabique IPA',
      category: 'Antidotes & Sérums',
      route: 'IM / Infiltration',
      indication: 'Exposition suspecte de rage (morsure, griffure Catégorie II et III - Guide IPA/OMS)',
      dose: '• Protocole Zagreb : 2 doses à J0 (1 dans chaque deltoïde), 1 dose à J7, 1 dose à J21\n• Sérum (Catégorie III) : 20 UI/kg infiltré dans et autour de la plaie',
      alert: 'Ne pas suturer immédiatement ! Nettoyage abondant à l\'eau et au savon pendant 15 minutes obligatoire.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();

    final filteredDrugs = _allDrugs.where((drug) {
      final matchesCategory = _selectedCategory == 'Tous' || drug.category == _selectedCategory;
      if (!matchesCategory) return false;

      if (query.isEmpty) return true;

      return drug.dci.toLowerCase().contains(query) ||
          drug.brand.toLowerCase().contains(query) ||
          drug.indication.toLowerCase().contains(query) ||
          drug.category.toLowerCase().contains(query) ||
          drug.route.toLowerCase().contains(query) ||
          drug.dose.toLowerCase().contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Collapsible Triage Banner
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _triageExpanded = !_triageExpanded),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF2563EB), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Triage National des Urgences (MSPRH Algérie)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        _triageExpanded ? 'Masquer' : 'Afficher',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _triageExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF2563EB),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (_triageExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _buildTriageLevel(
                        code: 'U1 - CODE ROUGE',
                        delay: '< 5 min',
                        title: 'Urgence Vitale Immédiate',
                        desc: 'Arrêt cardiorespiratoire, choc, détresse respiratoire aiguë, coma, polytraumatisé. Salle de déchoquage immédiate.',
                        color: const Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 8),
                      _buildTriageLevel(
                        code: 'U2 - CODE ORANGE',
                        delay: '< 30 min',
                        title: 'Urgence Grave Différée',
                        desc: 'Douleur thoracique aiguë, déficit neurologique (AVC), fracture ouverte, colique néphrétique hyperalgique, hémorragie contrôlée.',
                        color: const Color(0xFFD97706),
                      ),
                      const SizedBox(height: 8),
                      _buildTriageLevel(
                        code: 'U3 - CODE VERT',
                        delay: '> 60 min',
                        title: 'Urgence Relative / Ambulatoire',
                        desc: 'Fonctions vitales normales. Traumatismes mineurs, sutures simples. Orientation vers les polycliniques.',
                        color: const Color(0xFF16A34A),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Search Bar Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher par DCI, marque Saidal/IPA, indication (ACR, OAP, sepsis)...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryTeal),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkSurfaceElevated
                      : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 10),

              // Categories Horizontal Scroll
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppTheme.primaryTeal : null,
                        ),
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // Results counter
              Row(
                children: [
                  Text(
                    '${filteredDrugs.length} molécule${filteredDrugs.length > 1 ? 's' : ''} disponible${filteredDrugs.length > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedCategory != 'Tous') ...[
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 20),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => setState(() {
                        _searchQuery = '';
                        _selectedCategory = 'Tous';
                      }),
                      child: const Text('Réinitialiser les filtres', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Drug Cards List
        if (filteredDrugs.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.medication_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('Aucun médicament trouvé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'Aucune molécule ne correspond à "${_searchQuery.isNotEmpty ? _searchQuery : _selectedCategory}".',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...filteredDrugs.map((drug) => _buildDrugCard(drug)),
      ],
    );
  }

  Widget _buildTriageLevel({
    required String code,
    required String delay,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                child: Text(code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              const Spacer(),
              Text('Délai : $delay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildDrugCard(EmergencyDrugItem drug) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: DCI, Brand, Category, Route
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drug.dci,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        drug.brand,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        drug.route,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Indication
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎯 ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text(
                    drug.indication,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Posologie Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 Posologie & Administration :',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryDarkTeal),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    drug.dose,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Alert Row
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.2 : 0.6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      drug.alert,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // AI Copilot Action Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: BorderSide(color: const Color(0xFF2563EB).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text(
                  'Précisions Posologie & Adaptation avec le Copilote Gemini ✨',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  ClinicalCopilotSheet.show(
                    context,
                    initialSituation: 'Posologie, adaptation et précautions pour ${drug.dci} (${drug.brand}) dans l\'indication : ${drug.indication}.',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
