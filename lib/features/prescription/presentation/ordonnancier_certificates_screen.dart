import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../models/medical_templates_model.dart';
import '../services/medical_document_pdf_exporter.dart';

class OrdonnancierCertificatesScreen extends StatefulWidget {
  final int initialTab;
  const OrdonnancierCertificatesScreen({super.key, this.initialTab = 0});

  @override
  State<OrdonnancierCertificatesScreen> createState() =>
      _OrdonnancierCertificatesScreenState();
}

class _OrdonnancierCertificatesScreenState
    extends State<OrdonnancierCertificatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _isPediatricMode = false;
  double _pediatricWeightKg = 18.0;

  late final TextEditingController _doctorCtrl;
  final _establishmentCtrl = TextEditingController(text: 'CHU / EPSP de Garde');
  final _cityCtrl = TextEditingController(text: 'Blida');
  final _patientNameCtrl = TextEditingController();
  final _patientAgeCtrl = TextEditingController(text: '32');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    final user = context.read<AuthBloc>().state.user;
    _doctorCtrl = TextEditingController(
      text: user != null && user.fullName.isNotEmpty
          ? 'Dr. ${user.fullName}'
          : 'Dr. Médecin',
    );
    if (user?.wilaya != null && user!.wilaya!.isNotEmpty) {
      _cityCtrl.text = user.wilaya!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _doctorCtrl.dispose();
    _establishmentCtrl.dispose();
    _cityCtrl.dispose();
    _patientNameCtrl.dispose();
    _patientAgeCtrl.dispose();
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
              'Ordonnancier & Certificats Algérie',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Ordonnances Types DCI/CNAS • CBV/ITT • Export PDF A4',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryTeal,
          labelColor: AppTheme.primaryTeal,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Ordonnances Types'),
            Tab(icon: Icon(Icons.gavel_rounded, size: 18), text: 'Certificats Médico-Légaux'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filtrer une pathologie ou certificat (ex: Angine, CBV, Asthme)...',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPrescriptionsTab(),
                _buildCertificatesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsTab() {
    final filtered = MedicalTemplatesCatalog.prescriptions.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.title.toLowerCase().contains(_searchQuery) ||
          p.specialty.toLowerCase().contains(_searchQuery) ||
          p.clinicalContext.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.bentoCardDecoration(context, radius: 16),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Mode Pédiatrique (Calcul automatique mg/kg/j)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Adapte automatiquement les posologies pédiatriques au poids de l\'enfant',
                  style: TextStyle(fontSize: 11.5),
                ),
                value: _isPediatricMode,
                activeTrackColor: AppTheme.primaryTeal,
                onChanged: (v) => setState(() => _isPediatricMode = v),
              ),
              if (_isPediatricMode) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Poids de l\'enfant :', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${_pediatricWeightKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryTeal, fontSize: 15),
                    ),
                  ],
                ),
                Slider(
                  value: _pediatricWeightKg,
                  min: 4,
                  max: 45,
                  divisions: 41,
                  activeColor: AppTheme.primaryTeal,
                  onChanged: (v) => setState(() => _pediatricWeightKg = v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...filtered.map((tpl) => _buildPrescriptionCard(tpl)),
      ],
    );
  }

  Widget _buildPrescriptionCard(PrescriptionTemplate tpl) {
    final formattedBody = tpl.lines
        .asMap()
        .entries
        .map((e) =>
            '${e.key + 1}. ${e.value.formatForPatient(isPediatric: _isPediatricMode && tpl.supportsPediatricWeight, weightKg: _pediatricWeightKg)}')
        .join('\n\n');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.medication_rounded, color: AppTheme.primaryTeal),
        ),
        title: Text(tpl.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
        subtitle: Text('${tpl.specialty} • ${tpl.clinicalContext}', style: const TextStyle(fontSize: 11.5)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              formattedBody,
              style: const TextStyle(fontSize: 12.5, height: 1.45),
            ),
          ),
          if (tpl.contraindicationsAlert.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...tpl.contraindicationsAlert.map(
              (a) => Text('⚠ $a', style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text('Copier'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: formattedBody));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ordonnance copiée dans le presse-papiers')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                  label: const Text('Exporter PDF A4'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _openPdfExportDialog(
                    docTitle: 'Ordonnance Médicale — ${tpl.title}',
                    initialBody: formattedBody,
                    fileName: 'ordonnance_${tpl.id}',
                    isPrescription: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatesTab() {
    final filtered = MedicalTemplatesCatalog.certificates.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.title.toLowerCase().contains(_searchQuery) ||
          c.legalCategory.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final cert = filtered[index];
        return Card(
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.gavel_rounded, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cert.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          Text(cert.legalReferenceDz, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (cert.medicoLegalReminders.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...cert.medicoLegalReminders.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('⚖️ $r', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_document, size: 18),
                    label: const Text('Remplir & Générer le Certificat PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.clinicalNavy,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _openCertificateBuilder(cert),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCertificateBuilder(MedicoLegalCertificateTemplate cert) async {
    final findingsCtrl = TextEditingController();
    int ittDays = 7;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cert.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(controller: _doctorCtrl, decoration: const InputDecoration(labelText: 'Nom du Médecin', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _establishmentCtrl, decoration: const InputDecoration(labelText: 'Établissement (CHU / EPSP)', isDense: true)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _patientNameCtrl, decoration: const InputDecoration(labelText: 'Nom du Patient', isDense: true))),
                    const SizedBox(width: 8),
                    SizedBox(width: 90, child: TextField(controller: _patientAgeCtrl, decoration: const InputDecoration(labelText: 'Âge', isDense: true))),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: findingsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Constatations cliniques / Description lésionnelle',
                    hintText: 'Ex: Ecchymose périorbitaire gauche 3x2 cm, dermabrasion...',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (cert.includesIttDays) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Durée ITT / Repos (jours) :', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        '$ittDays jours ${ittDays > 15 ? "(> 15j : Délit)" : "(≤ 15j)"}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: ittDays > 15 ? const Color(0xFFDC2626) : AppTheme.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: ittDays.toDouble(),
                    min: 1,
                    max: 45,
                    divisions: 44,
                    activeColor: AppTheme.primaryTeal,
                    onChanged: (v) => setSheetState(() => ittDays = v.round()),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Générer PDF A4 Officiel'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                    onPressed: () async {
                      final rendered = cert.renderBody(
                        doctorName: _doctorCtrl.text,
                        establishment: _establishmentCtrl.text,
                        patientName: _patientNameCtrl.text,
                        patientAge: _patientAgeCtrl.text,
                        findingsOrReason: findingsCtrl.text,
                        ittDays: ittDays,
                        city: _cityCtrl.text,
                      );
                      Navigator.pop(ctx);
                      await _exportPdf(
                        docTitle: cert.title,
                        bodyContent: rendered,
                        fileName: cert.id,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPdfExportDialog({
    required String docTitle,
    required String initialBody,
    required String fileName,
    bool isPrescription = false,
  }) async {
    final bodyCtrl = TextEditingController(text: initialBody);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(docTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 10),
              TextField(controller: _doctorCtrl, decoration: const InputDecoration(labelText: 'Médecin', isDense: true)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _patientNameCtrl, decoration: const InputDecoration(labelText: 'Patient(e)', isDense: true))),
                  const SizedBox(width: 8),
                  SizedBox(width: 90, child: TextField(controller: _patientAgeCtrl, decoration: const InputDecoration(labelText: 'Âge', isDense: true))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bodyCtrl,
                maxLines: 7,
                decoration: const InputDecoration(labelText: 'Contenu modifiable', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Télécharger / Ouvrir le PDF A4'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _exportPdf(
                      docTitle: isPrescription ? 'ORDONNANCE MÉDICALE' : docTitle,
                      bodyContent: bodyCtrl.text,
                      fileName: fileName,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf({
    required String docTitle,
    required String bodyContent,
    required String fileName,
  }) async {
    try {
      final path = await MedicalDocumentPdfExporter.exportAndOpenPdf(
        fileName: fileName,
        documentTitle: docTitle,
        doctorName: _doctorCtrl.text,
        establishment: _establishmentCtrl.text,
        city: _cityCtrl.text,
        patientName: _patientNameCtrl.text,
        patientMeta: _patientAgeCtrl.text.isNotEmpty ? '(${_patientAgeCtrl.text} ans)' : '',
        bodyContent: bodyContent,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(path != null ? 'PDF exporté : $path' : 'PDF généré avec succès'),
            backgroundColor: AppTheme.primaryTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export PDF : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
