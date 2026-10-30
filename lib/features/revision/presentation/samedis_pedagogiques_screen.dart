import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/module_model.dart';
import '../models/samedi_pedagogique_model.dart';
import 'course_pdf_viewer_screen.dart';

class SamedisPedagogiquesScreen extends StatefulWidget {
  const SamedisPedagogiquesScreen({super.key});

  @override
  State<SamedisPedagogiquesScreen> createState() =>
      _SamedisPedagogiquesScreenState();
}

class _SamedisPedagogiquesScreenState extends State<SamedisPedagogiquesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SamediPedagogiqueItem> _allItems = [];
  List<SamediPedagogiqueItem> _filteredItems = [];
  bool _isLoading = true;
  String _selectedSpecialty = 'Toutes';

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final jsonStr = await rootBundle
          .loadString('assets/data/samedis_pedagogiques.json');
      final list = json.decode(jsonStr) as List<dynamic>;
      _allItems = list
          .map((e) => SamediPedagogiqueItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Erreur chargement Samedis Pédagogiques: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _applyFilter();
        });
      }
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((it) {
        final matchesQuery = query.isEmpty ||
            it.title.toLowerCase().contains(query) ||
            it.specialty.toLowerCase().contains(query) ||
            it.description.toLowerCase().contains(query) ||
            it.keywords.any((k) => k.contains(query));

        final matchesSpec = _selectedSpecialty == 'Toutes' ||
            it.specialty == _selectedSpecialty ||
            it.module == _selectedSpecialty;

        return matchesQuery && matchesSpec;
      }).toList();
    });
  }

  void _openPdfViewer(SamediPedagogiqueItem item) {
    final mockCourse = CourseModel(
      id: item.id,
      moduleId: item.module,
      name: item.title,
      questionsCount: 0,
      hasPdf: true,
      pdfDownloadUrl: item.assetPath,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoursePdfViewerScreen(
          course: mockCourse,
          moduleName: 'Samedis Pédagogiques • ${item.specialty}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final specialties = [
      'Toutes',
      ...{..._allItems.map((e) => e.specialty)}
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF0FDFA),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFCCFBF1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: AppTheme.primaryTeal,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Samedis Pédagogiques (SP)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryTeal,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${_allItems.length} Séances Complètes',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dossiers cliniques, QCS de séance, cas cliniques corrigés et fiches réflexes de révision des Samedis Pédagogiques.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search & Filter Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText:
                                'Rechercher un dossier (ex: Choc septique, GEU, Côlon, Cas cliniques...)',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Specialty Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: specialties.map((spec) {
                      final isSelected = _selectedSpecialty == spec;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            spec,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade800),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryTeal,
                          onSelected: (_) {
                            setState(() {
                              _selectedSpecialty = spec;
                              _applyFilter();
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(height: 16),

                // Items Grid / List
                Expanded(
                  child: _filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'Aucun dossier ne correspond à votre recherche.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _filteredItems.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final it = _filteredItems[index];
                            return _buildItemCard(context, it, isDark);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildItemCard(
      BuildContext context, SamediPedagogiqueItem it, bool isDark) {
    Color typeColor = AppTheme.primaryTeal;
    IconData typeIcon = Icons.menu_book_rounded;

    if (it.type == 'cas_clinique') {
      typeColor = const Color(0xFFF59E0B);
      typeIcon = Icons.psychology_alt_rounded;
    } else if (it.type == 'qcs') {
      typeColor = const Color(0xFF6366F1);
      typeIcon = Icons.quiz_rounded;
    } else if (it.type == 'planning') {
      typeColor = const Color(0xFF10B981);
      typeIcon = Icons.calendar_month_rounded;
    }

    return Card(
      elevation: isDark ? 0 : 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: () => _openPdfViewer(it),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 26),
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
                              horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            it.typeLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${it.specialty}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${it.pagesCount} pages • ${(it.sizeKb > 1024) ? "${(it.sizeKb / 1024).toStringAsFixed(1)} Mo" : "${it.sizeKb.toStringAsFixed(0)} Ko"}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      it.title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      it.description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text(
                  'Lire',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _openPdfViewer(it),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
