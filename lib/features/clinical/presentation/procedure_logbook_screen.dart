import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/clinical_procedure_logbook_model.dart';

class ProcedureLogbookScreen extends StatefulWidget {
  final int initialTab;
  const ProcedureLogbookScreen({super.key, this.initialTab = 0});

  @override
  State<ProcedureLogbookScreen> createState() => _ProcedureLogbookScreenState();
}

class _ProcedureLogbookScreenState extends State<ProcedureLogbookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ProcedureLogEntry> _logs = [];
  final Map<String, Set<int>> _checkedEquipments = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await ProcedureLogbookRepository.loadLogs();
    if (mounted) setState(() => _logs = logs);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
              'Gestes de Garde & Carnet de Stage',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Check-lists Chariot Stérile • Suivi d\'Autonomie Externe/Interne',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryTeal,
          labelColor: AppTheme.primaryTeal,
          tabs: [
            const Tab(icon: Icon(Icons.checklist_rounded, size: 18), text: 'Fiches & Check-lists'),
            Tab(icon: const Icon(Icons.fact_check_rounded, size: 18), text: 'Mon Logbook (${_logs.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGuidesTab(),
          _buildLogbookTab(),
        ],
      ),
    );
  }

  Widget _buildGuidesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ProcedureLogbookRepository.guides.length,
      itemBuilder: (context, idx) {
        final guide = ProcedureLogbookRepository.guides[idx];
        final checkedSet = _checkedEquipments.putIfAbsent(guide.id, () => <int>{});
        final autonomousCount = _logs
            .where((l) => l.procedureId == guide.id && l.autonomyLevel == ProcedureAutonomyLevel.autonomous)
            .length;
        final progress = (autonomousCount / guide.targetAutonomousCount).clamp(0.0, 1.0);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medical_information_rounded, color: AppTheme.primaryTeal),
            ),
            title: Text(guide.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guide.specialty, style: const TextStyle(fontSize: 11.5)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                  color: AppTheme.primaryTeal,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 2),
                Text(
                  'Autonomie : $autonomousCount / ${guide.targetAutonomousCount} gestes validés',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _sectionTitle('🚨 Contre-Indications Absolues (Red Flags)', const Color(0xFFDC2626)),
              ...guide.contraindicationsRedFlags.map((c) => Text('• $c', style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600))),
              const SizedBox(height: 10),
              _sectionTitle('🧰 Check-list Matériel sur le Chariot', AppTheme.primaryTeal),
              ...guide.equipmentChecklist.asMap().entries.map((e) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: checkedSet.contains(e.key),
                    activeColor: AppTheme.primaryTeal,
                    title: Text(e.value, style: const TextStyle(fontSize: 12.5)),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          checkedSet.add(e.key);
                        } else {
                          checkedSet.remove(e.key);
                        }
                      });
                    },
                  )),
              const SizedBox(height: 8),
              _sectionTitle('📋 Étapes Techniques Aseptiques', AppTheme.clinicalNavy),
              ...guide.steps.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${e.key + 1}. ${e.value}', style: const TextStyle(fontSize: 12.5)),
                  )),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('🩺 Surveillance : ${guide.postProcedureCare}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Enregistrer ce geste dans mon Logbook'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                  onPressed: () => _openLogDialog(guide),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: color)),
      ),
    );
  }

  Widget _buildLogbookTab() {
    if (_logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Aucun geste enregistré pour le moment.\nOuvrez une fiche technique pour valider votre premier geste de stage ou de garde !',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, idx) {
        final log = _logs[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: log.autonomyLevel == ProcedureAutonomyLevel.autonomous
                  ? AppTheme.primaryTeal.withValues(alpha: 0.15)
                  : Colors.amber.withValues(alpha: 0.15),
              child: Icon(
                log.autonomyLevel == ProcedureAutonomyLevel.autonomous
                    ? Icons.verified_rounded
                    : Icons.visibility_rounded,
                color: log.autonomyLevel == ProcedureAutonomyLevel.autonomous
                    ? AppTheme.primaryTeal
                    : Colors.amber.shade700,
              ),
            ),
            title: Text(log.procedureTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            subtitle: Text(
              '${log.hospitalService} • ${DateFormat('dd/MM/yyyy').format(log.performedAt)}${log.notes != null && log.notes!.isNotEmpty ? '\n${log.notes}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Chip(
              label: Text(log.autonomyLevel.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLogDialog(ClinicalProcedureGuide guide) async {
    final serviceCtrl = TextEditingController(text: 'Pavillon des Urgences / CHU');
    final notesCtrl = TextEditingController();
    ProcedureAutonomyLevel level = ProcedureAutonomyLevel.autonomous;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Valider : ${guide.title}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: serviceCtrl, decoration: const InputDecoration(labelText: 'Service / Hôpital')),
              const SizedBox(height: 10),
              DropdownButtonFormField<ProcedureAutonomyLevel>(
                initialValue: level,
                decoration: const InputDecoration(labelText: 'Niveau d\'autonomie'),
                items: ProcedureAutonomyLevel.values
                    .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
                    .toList(),
                onChanged: (v) => setDlgState(() => level = v ?? ProcedureAutonomyLevel.observed),
              ),
              const SizedBox(height: 8),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Remarques (optionnel)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final entry = ProcedureLogEntry(
                  id: 'log_${DateTime.now().millisecondsSinceEpoch}',
                  procedureId: guide.id,
                  procedureTitle: guide.title,
                  hospitalService: serviceCtrl.text.trim(),
                  autonomyLevel: level,
                  notes: notesCtrl.text.trim(),
                  performedAt: DateTime.now(),
                );
                await ProcedureLogbookRepository.addLog(entry);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadLogs();
                _tabController.animateTo(1);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
