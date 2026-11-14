import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medsina_core/core/network/supabase_service.dart';
import 'package:medsina_core/core/theme/app_theme.dart';
import 'package:medsina_core/core/widgets/medsina_dialog.dart';
import 'package:medsina_study_engine/features/revision/models/module_model.dart';
import '../models/temoignage_conseil_model.dart';
import 'package:medsina_study_engine/features/revision/presentation/course_pdf_viewer_screen.dart';

class TemoignagesConseilsScreen extends StatefulWidget {
  const TemoignagesConseilsScreen({super.key});

  @override
  State<TemoignagesConseilsScreen> createState() =>
      _TemoignagesConseilsScreenState();
}

class _TemoignagesConseilsScreenState extends State<TemoignagesConseilsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<TemoignageConseilItem> _allItems = [];
  List<TemoignageConseilItem> _filteredItems = [];
  bool _isLoading = true;
  String _selectedFilter = 'Tous'; // 'Tous', 'Blida 2026 🏆', 'Majors Historiques', 'PDFs Disponibles'

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
    final Map<String, TemoignageConseilItem> itemsMap = {};

    // 1. Charge d'abord les témoignages locaux (embarqués dans l'App pour révision 100% hors-ligne)
    try {
      final jsonStr = await rootBundle
          .loadString('assets/data/temoignages_conseils.json');
      final list = json.decode(jsonStr) as List<dynamic>;
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final item = TemoignageConseilItem.fromJson(e);
          itemsMap[item.id] = item;
        }
      }
    } catch (e) {
      debugPrint('Notice: Local temoignages_conseils.json load: $e');
    }

    if (mounted && itemsMap.isNotEmpty) {
      final list = itemsMap.values.toList()
        ..sort((a, b) => a.rankNumber.compareTo(b.rankNumber));
      setState(() {
        _allItems = list;
        _isLoading = false;
        _applyFilter();
      });
    }

    // 2. Récupère en direct depuis la base de données Supabase Cloud
    // Cela permet d'ajouter des témoignages sans republier l'application mobile !
    try {
      final remoteRows = await SupabaseService.fetchTemoignagesConseils();
      if (remoteRows.isNotEmpty) {
        for (final row in remoteRows) {
          final item = TemoignageConseilItem.fromJson(row);
          itemsMap[item.id] = item;
        }
        final mergedList = itemsMap.values.toList()
          ..sort((a, b) => a.rankNumber.compareTo(b.rankNumber));
        if (mounted) {
          setState(() {
            _allItems = mergedList;
            _isLoading = false;
            _applyFilter();
          });
        }
      }
    } catch (e) {
      debugPrint('Notice: Supabase fetchTemoignagesConseils error: $e');
    } finally {
      if (mounted && _isLoading) {
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
            it.name.toLowerCase().contains(query) ||
            it.faculty.toLowerCase().contains(query) ||
            it.rankBadge.toLowerCase().contains(query) ||
            it.summary.toLowerCase().contains(query) ||
            it.keyAdvices.any((k) => k.toLowerCase().contains(query));

        bool matchesCategory = true;
        if (_selectedFilter == 'Blida 2026 🏆') {
          matchesCategory = it.isRecent2026;
        } else if (_selectedFilter == 'Majors Historiques') {
          matchesCategory = !it.isRecent2026;
        } else if (_selectedFilter == 'PDFs Disponibles') {
          matchesCategory = it.assetPdfPath != null;
        }

        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  void _openPdfViewer(TemoignageConseilItem item, {bool isExtra = false}) {
    final titleSuffix = isExtra ? ' (Complément)' : '';
    final driveId = isExtra ? item.extraGdriveId : item.gdriveId;
    final pdfPath = isExtra ? item.extraAssetPdfPath : item.assetPdfPath;

    final effectiveDriveId = driveId ??
        (item.targetUrl != null && item.targetUrl!.contains('/d/')
            ? item.targetUrl!.split('/d/')[1].split('/')[0].split('?')[0]
            : null);

    if (pdfPath == null && (effectiveDriveId == null || effectiveDriveId.isEmpty)) {
      if (item.targetUrl != null && item.targetUrl!.isNotEmpty) {
        _openExternalUrl(item.targetUrl!);
      }
      return;
    }

    final mockCourse = CourseModel(
      id: '${item.id}${isExtra ? "_extra" : ""}',
      moduleId: 'temoignages',
      name: '${item.name}$titleSuffix',
      questionsCount: 0,
      hasPdf: true,
      pdfDownloadUrl: effectiveDriveId != null
          ? 'https://drive.usercontent.google.com/download?id=$effectiveDriveId&export=download&confirm=t'
          : (pdfPath ?? ''),
      pdfDriveId: effectiveDriveId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoursePdfViewerScreen(
          course: mockCourse,
          moduleName: 'Témoignages & Conseils • ${item.rankBadge}',
        ),
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          MedsinaDialog.error(
            context,
            title: 'Lien inaccessible',
            message: 'Impossible d\'ouvrir le lien demandé.',
            detail: url,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        MedsinaDialog.error(
          context,
          title: 'Erreur d\'ouverture',
          message: 'Impossible d\'ouvrir le lien.',
          detail: '$e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : RefreshIndicator(
              onRefresh: _loadItems,
              color: AppTheme.primaryTeal,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderBanner(isDark),
                          const SizedBox(height: 16),
                          _buildSearchBar(isDark),
                          const SizedBox(height: 12),
                          _buildFilterChips(isDark),
                          const SizedBox(height: 8),
                          Text(
                            '${_filteredItems.length} retour${_filteredItems.length > 1 ? "s" : ""} d\'expérience & stratégies',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  _filteredItems.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 64,
                                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun témoignage trouvé',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Essayez d\'ajuster vos filtres de recherche',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.crossAxisExtent > 768;
                              if (isWide) {
                                return SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 600,
                                    mainAxisExtent: 440,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _buildCard(
                                      _filteredItems[index],
                                      isDark,
                                    ),
                                    childCount: _filteredItems.length,
                                  ),
                                );
                              }
                              return SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildCard(
                                      _filteredItems[index],
                                      isDark,
                                    ),
                                  ),
                                  childCount: _filteredItems.length,
                                ),
                              );
                            },
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A8A), const Color(0xFF0F766E)]
              : [const Color(0xFFE0E7FF), const Color(0xFFCCFBF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.blue.withAlpha(70)
              : Colors.blue.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.blue.withAlpha(60)
                  : Colors.blue.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.military_tech_rounded,
              color: Color(0xFF2563EB),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Témoignages & Conseils des Majors',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Retours d\'expérience, méthodologies de révision et fiches morales des Majors de Blida et des facultés algériennes.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Rechercher un major, une faculté, un conseil...',
        hintStyle: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[400],
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppTheme.primaryTeal,
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 20),
                onPressed: () => _searchController.clear(),
              )
            : null,
        filled: true,
        fillColor: isDark ? AppTheme.darkSurface : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.primaryTeal,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = ['Tous', 'Blida 2026 🏆', 'Majors Historiques', 'PDFs Disponibles'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = f;
                    _applyFilter();
                  });
                }
              },
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
              selectedColor: f.contains('2026') ? Colors.amber[800] : AppTheme.primaryTeal,
              backgroundColor: isDark ? AppTheme.darkSurface : Colors.grey[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard(TemoignageConseilItem item, bool isDark) {
    final hasLocalPdf = item.assetPdfPath != null;
    final hasExtraPdf = item.extraAssetPdfPath != null;
    final hasDriveUrl = item.targetUrl != null && item.targetUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isRecent2026
              ? Colors.amber.withAlpha(120)
              : (isDark ? Colors.grey[850]! : Colors.grey[200]!),
          width: item.isRecent2026 ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Avatar + Name + Rank Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: item.isRecent2026
                      ? Colors.amber.withAlpha(40)
                      : AppTheme.primaryTeal.withAlpha(30),
                  child: Text(
                    item.name.replaceFirst('Dr ', '').substring(0, 1),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: item.isRecent2026
                          ? Colors.amber[800]
                          : AppTheme.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.isRecent2026
                                  ? Colors.amber.withAlpha(30)
                                  : Colors.blue.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: item.isRecent2026
                                    ? Colors.amber.withAlpha(150)
                                    : Colors.blue.withAlpha(80),
                              ),
                            ),
                            child: Text(
                              item.rankBadge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.isRecent2026
                                    ? (isDark ? Colors.amber[300] : Colors.amber[900])
                                    : (isDark ? Colors.blue[300] : Colors.blue[700]),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.faculty} • Promotion ${item.year}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Summary
            Text(
              item.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: isDark ? Colors.grey[300] : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 10),

            // Key Advices Box
            if (item.keyAdvices.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: item.keyAdvices.take(2).map((adv) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 15,
                            color: item.isRecent2026 ? Colors.amber[700] : AppTheme.primaryTeal,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              adv,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.25,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 12),

            // Recommended sources if available
            if (item.recommendedSources.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sources : ${item.recommendedSources}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (hasLocalPdf)
                  FilledButton.icon(
                    onPressed: () => _openPdfViewer(item),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('Lire le Guide PDF', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (hasExtraPdf)
                  OutlinedButton.icon(
                    onPressed: () => _openPdfViewer(item, isExtra: true),
                    icon: const Icon(Icons.description_rounded, size: 16),
                    label: const Text('Fiche QCM', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryTeal,
                      side: const BorderSide(color: AppTheme.primaryTeal),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (hasDriveUrl)
                  OutlinedButton.icon(
                    onPressed: () => _openExternalUrl(item.targetUrl!),
                    icon: const Icon(Icons.cloud_download_rounded, size: 16),
                    label: Text(
                      item.documentType == 'gdrive_folder'
                          ? 'Dossier Drive'
                          : 'Drive Officiel',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: item.isRecent2026
                          ? (isDark ? Colors.amber[300] : Colors.amber[900])
                          : (isDark ? Colors.blue[300] : Colors.blue[700]),
                      side: BorderSide(
                        color: item.isRecent2026
                            ? Colors.amber[700]!
                            : Colors.blue[600]!,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (item.gdriveFolderUrl != null && item.gdriveFolderUrl!.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _openExternalUrl(item.gdriveFolderUrl!),
                    icon: const Icon(Icons.folder_shared_rounded, size: 16),
                    label: const Text('Méga-Drive', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: item.isRecent2026
                          ? (isDark ? Colors.amber[300] : Colors.amber[900])
                          : (isDark ? Colors.blue[300] : Colors.blue[700]),
                      side: BorderSide(
                        color: item.isRecent2026
                            ? Colors.amber[700]!
                            : Colors.blue[600]!,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (item.telegramUrl != null && item.telegramUrl!.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _openExternalUrl(item.telegramUrl!),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Canal Telegram', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

