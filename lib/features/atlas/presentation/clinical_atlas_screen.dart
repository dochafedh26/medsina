import 'package:flutter/material.dart';
import '../../../core/theme/medsina_colors.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/clinical_atlas_repository.dart';
import '../models/clinical_atlas_model.dart';

class ClinicalAtlasScreen extends StatefulWidget {
  const ClinicalAtlasScreen({super.key});

  @override
  State<ClinicalAtlasScreen> createState() => _ClinicalAtlasScreenState();
}

class _ClinicalAtlasScreenState extends State<ClinicalAtlasScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<ClinicalAtlasCase> _allCases = [];
  bool _loading = true;
  ClinicalModality? _selectedModality;
  String _selectedSpecialty = 'Toutes';
  bool _examMode = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cases = await ClinicalAtlasRepository.instance.loadCases();
    if (!mounted) return;
    setState(() {
      _allCases = cases;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final specialties = <String>{
      'Toutes',
      ..._allCases.map((c) => c.specialty),
    }.toList();

    final filtered = ClinicalAtlasRepository.filterCases(
      _allCases,
      modality: _selectedModality,
      specialty: _selectedSpecialty,
      query: _searchCtrl.text,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atlas d\'Images Cliniques'),
        actions: [
          Tooltip(
            message: _examMode
                ? 'Mode Examen (diagnostic masqué)'
                : 'Mode Correction (tout affiché)',
            child: FilterChip(
              selected: _examMode,
              label: Text(_examMode ? 'Mode Examen' : 'Correction'),
              avatar: Icon(
                _examMode ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 16,
              ),
              onSelected: (v) => setState(() => _examMode = v),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher ECG, radio, TDM, diagnostic...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Toutes modalités'),
                    selected: _selectedModality == null,
                    onSelected: (_) => setState(() => _selectedModality = null),
                  ),
                ),
                ...ClinicalModality.values.map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(m.icon, size: 16, color: m.color),
                      label: Text(m.label),
                      selected: _selectedModality == m,
                      onSelected: (sel) => setState(
                        () => _selectedModality = sel ? m : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: specialties.map((sp) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(sp),
                    selected: _selectedSpecialty == sp,
                    onSelected: (_) => setState(() => _selectedSpecialty = sp),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const SkeletonCardList(itemCount: 5, itemHeight: 112)
                : filtered.isEmpty
                    ? EmptyStateView(
                        icon: Icons.image_search_rounded,
                        title: 'Aucun cas iconographique trouvé',
                        subtitle:
                            'Essayez une autre spécialité ou réinitialisez vos filtres.',
                        actionLabel: 'Tout afficher',
                        onAction: () {
                          _searchCtrl.clear();
                          setState(() {
                            _selectedModality = null;
                            _selectedSpecialty = 'Toutes';
                          });
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _AtlasCaseCard(
                            atlasCase: item,
                            mc: mc,
                            onTap: () => _openCaseDetail(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _openCaseDetail(ClinicalAtlasCase item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AtlasCaseDetailScreen(
          atlasCase: item,
          initialExamMode: _examMode,
        ),
      ),
    );
  }
}

class _AtlasCaseCard extends StatelessWidget {
  final ClinicalAtlasCase atlasCase;
  final MedsinaColors mc;
  final VoidCallback onTap;

  const _AtlasCaseCard({
    required this.atlasCase,
    required this.mc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mod = atlasCase.modality;
    return Semantics(
      button: true,
      label: '${atlasCase.title}, ${atlasCase.specialty}, ${mod.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: mc.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: mc.border),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: mod.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: mod.color.withValues(alpha: 0.3)),
                ),
                child: atlasCase.imageUrl != null &&
                        atlasCase.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(
                          atlasCase.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(mod.icon, color: mod.color, size: 30),
                        ),
                      )
                    : Icon(mod.icon, color: mod.color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: mod.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            mod.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: mod.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            atlasCase.specialty,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: mc.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      atlasCase.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: mc.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      atlasCase.clinicalContext,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: mc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: mc.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AtlasCaseDetailScreen extends StatefulWidget {
  final ClinicalAtlasCase atlasCase;
  final bool initialExamMode;

  const _AtlasCaseDetailScreen({
    required this.atlasCase,
    required this.initialExamMode,
  });

  @override
  State<_AtlasCaseDetailScreen> createState() => _AtlasCaseDetailScreenState();
}

class _AtlasCaseDetailScreenState extends State<_AtlasCaseDetailScreen> {
  late bool _revealed;

  @override
  void initState() {
    super.initState();
    _revealed = !widget.initialExamMode;
  }

  @override
  Widget build(BuildContext context) {
    final mc = context.mc;
    final c = widget.atlasCase;
    final mod = c.modality;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.specialty),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _revealed = !_revealed),
            icon: Icon(
              _revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 18,
            ),
            label: Text(_revealed ? 'Masquer' : 'Révéler'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Zoomable Interactive Image / Schematic Viewer
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: mc.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: c.imageUrl != null && c.imageUrl!.isNotEmpty
                        ? Image.network(
                            c.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                _ClinicalPlaceholderCanvas(atlasCase: c),
                          )
                        : _ClinicalPlaceholderCanvas(atlasCase: c),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 15),
                        SizedBox(width: 4),
                        Text(
                          'Pincer pour zoomer',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Chip(
                avatar: Icon(mod.icon, size: 16, color: mod.color),
                label: Text(mod.label),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: c.tags
                      .map((t) => Chip(
                            label: Text(t, style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: mc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: mc.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contexte clinique',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: mc.accent,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(c.clinicalContext, style: TextStyle(color: mc.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!_revealed)
            ElevatedButton.icon(
              onPressed: () => setState(() => _revealed = true),
              icon: const Icon(Icons.psychology_rounded),
              label: const Text('Révéler les signes & le diagnostic'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: mc.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: mc.success.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diagnostic retenu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: mc.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.diagnosis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: mc.textPrimary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: mc.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: mc.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Signes sémiologiques clés',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: mc.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...c.keyFindings.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 17, color: mc.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(f, style: TextStyle(color: mc.textPrimary)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (c.differentialDiagnosis.isNotEmpty) ...[
                    const Divider(height: 22),
                    Text(
                      'Diagnostics différentiels',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: mc.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    ...c.differentialDiagnosis.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $d',
                            style: TextStyle(color: mc.textSecondary)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: mc.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: mc.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_rounded, color: mc.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Perle Concours Résidanat',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: mc.warning,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.highYieldPearl,
                          style: TextStyle(color: mc.textPrimary),
                        ),
                      ],
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
}

class _ClinicalPlaceholderCanvas extends StatelessWidget {
  final ClinicalAtlasCase atlasCase;

  const _ClinicalPlaceholderCanvas({required this.atlasCase});

  @override
  Widget build(BuildContext context) {
    final mod = atlasCase.modality;
    return Container(
      color: const Color(0xFF0A0F1A),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mod.icon, size: 56, color: mod.color),
            const SizedBox(height: 12),
            Text(
              atlasCase.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fiche iconographique ${mod.label} • Synchronisable via Supabase',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
