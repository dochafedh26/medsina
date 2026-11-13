import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medsina_core/core/theme/app_theme.dart';
import 'package:medsina_core/features/ai_assistant/presentation/clinical_copilot_sheet.dart';
import 'package:medsina_study_engine/features/revision/models/module_model.dart';
import 'package:medsina_study_engine/features/revision/presentation/course_pdf_viewer_screen.dart';

class CourseMindmapScreen extends StatefulWidget {
  final CourseModel course;
  final String? moduleName;

  const CourseMindmapScreen({
    super.key,
    required this.course,
    this.moduleName,
  });

  @override
  State<CourseMindmapScreen> createState() => _CourseMindmapScreenState();
}

class _CourseMindmapScreenState extends State<CourseMindmapScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _mindmapData;
  late TabController _viewModeController;
  int _expandedBranchIndex = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _viewModeController = TabController(length: 2, vsync: this);
    _loadMindmapData();
  }

  @override
  void dispose() {
    _viewModeController.dispose();
    super.dispose();
  }

  Future<void> _loadMindmapData() async {
    setState(() => _isLoading = true);
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/course_mindmaps.json');
      final Map<String, dynamic> allMindmaps = jsonDecode(jsonString);

      if (allMindmaps.containsKey(widget.course.id)) {
        if (mounted) {
          setState(() {
            _mindmapData = allMindmaps[widget.course.id];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _mindmapData = null;
        _isLoading = false;
      });
    }
  }

  String _resolvePdfUrl() {
    if (widget.course.mindmapPdfUrl != null &&
        widget.course.mindmapPdfUrl!.isNotEmpty) {
      return widget.course.mindmapPdfUrl!;
    }
    if (_mindmapData != null && _mindmapData!['mindmap_pdf_url'] != null) {
      return _mindmapData!['mindmap_pdf_url'];
    }
    return 'assets/mindmaps/${widget.course.id}_mindmap_residanat_2027.pdf';
  }

  void _openHdPdfViewer() {
    final pdfUrl = _resolvePdfUrl();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoursePdfViewerScreen(
          course: widget.course,
          moduleName: widget.moduleName,
          customPdfUrl: pdfUrl,
          customTitle: 'Mind Map 🧠 • ${widget.course.name}',
          isBooklet: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_rounded,
                    size: 18, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.course.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            Text(
              '${widget.moduleName ?? "Module"} • Mind Map Décisionnelle Concours',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded,
                color: Color(0xFFEF4444)),
            tooltip: 'Ouvrir Mind Map HD (PDF Grand Format)',
            onPressed: _openHdPdfViewer,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded,
                color: Colors.amberAccent),
            tooltip: 'Copilot IA : Explorer cette Carte Mentale',
            onPressed: () {
              ClinicalCopilotSheet.show(
                context,
                initialSituation:
                    'Explique-moi les branches diagnostiques et thérapeutiques de la Mind Map pour "${widget.course.name}" (${widget.moduleName ?? ""}).',
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _viewModeController,
          indicatorColor: const Color(0xFF8B5CF6),
          indicatorWeight: 3,
          labelColor: const Color(0xFF8B5CF6),
          unselectedLabelColor:
              isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.account_tree_outlined, size: 18),
              text: 'Arbre Interactif',
            ),
            Tab(
              icon: Icon(Icons.fullscreen_rounded, size: 18),
              text: 'Aperçu Vectoriel HD',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  SizedBox(height: 14),
                  Text('Chargement de la Mind Map médicale...'),
                ],
              ),
            )
          : TabBarView(
              controller: _viewModeController,
              children: [
                _buildInteractiveTreeView(isDark),
                _buildVectorPdfPreviewTab(isDark),
              ],
            ),
    );
  }

  Widget _buildInteractiveTreeView(bool isDark) {
    if (_mindmapData == null) {
      return _buildEmptyState(isDark);
    }

    final branches = _mindmapData!['branches'] as List<dynamic>? ?? [];
    final diag = _mindmapData!['diagnostic_criteria'] as String? ?? '';
    final treat = _mindmapData!['treatment_summary'] as String? ?? '';

    final filteredBranches = branches.where((b) {
      if (_searchQuery.isEmpty) return true;
      final title = (b['title'] ?? '').toString().toLowerCase();
      final items = (b['items'] as List<dynamic>? ?? [])
          .map((e) => e.toString().toLowerCase())
          .join(' ');
      return title.contains(_searchQuery.toLowerCase()) ||
          items.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Top Central Hub Card
        _buildCentralHubHeader(isDark),

        // Search Bar for nodes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Rechercher un seuil, médicament ou piège...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon:
                  const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF1E293B)
                  : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Interactive Branches List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: filteredBranches.length,
            itemBuilder: (context, idx) {
              final branch = filteredBranches[idx];
              final isExpanded = _expandedBranchIndex == idx;
              return _buildBranchCard(
                  branch, idx, isExpanded, isDark);
            },
          ),
        ),

        // Bottom Quick Insights Summary
        if (diag.isNotEmpty || treat.isNotEmpty)
          _buildBottomSummaryBar(diag, treat, isDark),
      ],
    );
  }

  Widget _buildCentralHubHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.hub_rounded,
              color: Colors.white,
              size: 26,
            ),
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
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CŒUR DU SUJET',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Résidanat 2027',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.course.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Arborescence clinique & décisionnelle synthétisée par IA',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard(
      dynamic branch, int index, bool isExpanded, bool isDark) {
    final title = branch['title'] as String? ?? 'Branche';
    final items = branch['items'] as List<dynamic>? ?? [];

    final colors = [
      const Color(0xFF0284C7), // Sky Blue
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEF4444), // Crimson
      const Color(0xFF10B981), // Emerald
      const Color(0xFF0D9488), // Teal
      const Color(0xFFF59E0B), // Amber
    ];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F38) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? color
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          width: isExpanded ? 1.5 : 1.0,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (exp) {
            setState(() {
              _expandedBranchIndex = exp ? index : -1;
            });
          },
          leading: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isExpanded ? color : null,
            ),
          ),
          trailing: Icon(
            isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: color,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: items.map((it) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6, right: 10),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            it.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: isDark
                                  ? Colors.grey.shade200
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSummaryBar(String diag, String treat, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (diag.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.fact_check_rounded,
                    size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                const Text(
                  'Diagnostic :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    diag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (treat.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.medication_rounded,
                    size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                const Text(
                  'Traitement :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    treat,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildVectorPdfPreviewTab(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                size: 64,
                color: Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Mind Map Vectorielle Haute Définition',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Format Paysage A3 conçu pour la mémorisation visuelle globale, l\'analyse des flux d\'urgence et la révision sur grand écran.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.fullscreen_rounded),
              label: const Text(
                'Ouvrir la Mind Map en Plein Écran',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _openHdPdfViewer,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10B981),
                side: const BorderSide(color: Color(0xFF10B981)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: const Text(
                'Stockage Google Drive 100% Cloud',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: _openHdPdfViewer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bubble_chart_rounded,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Mind Map en cours d\'optimisation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Le pipeline d\'ingestion Google Drive génère automatiquement les Mind Maps vectorielles pour l\'ensemble des 1 205 cours du catalogue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Consulter le Support PDF'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CoursePdfViewerScreen(
                      course: widget.course,
                      moduleName: widget.moduleName,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
