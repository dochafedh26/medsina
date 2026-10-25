import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';

class UserGuidePdfViewerScreen extends StatefulWidget {
  final int? initialPage;
  final String? initialSearchQuery;

  const UserGuidePdfViewerScreen({
    super.key,
    this.initialPage,
    this.initialSearchQuery,
  });

  static const String assetPath = 'assets/data/Medsina_Guide_Decouverte_Fonctionnalites.pdf';

  @override
  State<UserGuidePdfViewerScreen> createState() => _UserGuidePdfViewerScreenState();
}

class _UserGuidePdfViewerScreenState extends State<UserGuidePdfViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  int _pageCount = 6;
  bool _isDarkMode = false;
  bool _isSearching = false;
  PdfTextSearchResult? _searchResult;
  bool _isExporting = false;

  final List<Map<String, dynamic>> _chapters = [
    {'page': 1, 'title': '1. Vision & Architecture', 'icon': Icons.rocket_launch_rounded},
    {'page': 2, 'title': '2. Préparation Concours & QCMs', 'icon': Icons.menu_book_rounded},
    {'page': 3, 'title': '3. Pratique Clinique & Urgences', 'icon': Icons.emergency_rounded},
    {'page': 4, 'title': '4. IA Médicale & Outils Cognitifs', 'icon': Icons.psychology_rounded},
    {'page': 5, 'title': '5. Formules, Tarifs & Abonnements', 'icon': Icons.workspace_premium_rounded},
    {'page': 6, 'title': '6. Multiplateforme & Support', 'icon': Icons.devices_rounded},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchResult?.removeListener(_onSearchUpdate);
    super.dispose();
  }

  void _onSearchUpdate() {
    if (mounted) setState(() {});
  }

  void _executeSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _searchResult?.removeListener(_onSearchUpdate);
    _searchResult = _pdfController.searchText(trimmed);
    _searchResult?.addListener(_onSearchUpdate);
    setState(() {});
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchResult?.clear();
      _searchController.clear();
    });
  }

  Future<void> _openExternalPdf() async {
    setState(() => _isExporting = true);
    try {
      if (kIsWeb) {
        // On web, open the hosted PDF directly in a new tab
        const url = 'Medsina_Guide_Decouverte_Fonctionnalites.pdf';
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // On Android / Windows: write asset to temp file and launch default viewer
        final bytes = await rootBundle.load(UserGuidePdfViewerScreen.assetPath);
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/Medsina_Guide_Decouverte_Fonctionnalites.pdf');
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ouverture externe: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le fichier externe : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showTableOfContents() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.list_alt_rounded, color: AppTheme.primaryTeal),
                      const SizedBox(width: 10),
                      const Text(
                        'Sommaire du Guide Officiel',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _chapters.length,
                    itemBuilder: (c, idx) {
                      final item = _chapters[idx];
                      final isCurrent = _currentPage == item['page'];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isCurrent ? AppTheme.primaryTeal : Colors.grey.withValues(alpha: 0.15),
                          child: Icon(
                            item['icon'] as IconData,
                            size: 16,
                            color: isCurrent ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? AppTheme.primaryTeal : null,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Text(
                          'Page ${item['page']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? AppTheme.primaryTeal : Colors.grey,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _pdfController.jumpToPage(item['page'] as int);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isSearching ? _buildSearchBar() : _buildTitleBar(),
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Rechercher',
              onPressed: () => setState(() => _isSearching = true),
            ),
            IconButton(
              icon: const Icon(Icons.toc_rounded),
              tooltip: 'Sommaire',
              onPressed: _showTableOfContents,
            ),
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              tooltip: _isDarkMode ? 'Mode clair' : 'Mode sombre',
              onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
            ),
            if (isDesktop) ...[
              IconButton(
                icon: const Icon(Icons.zoom_in_rounded),
                tooltip: 'Zoom avant',
                onPressed: () => _pdfController.zoomLevel = (_pdfController.zoomLevel + 0.25).clamp(1.0, 3.0),
              ),
              IconButton(
                icon: const Icon(Icons.zoom_out_rounded),
                tooltip: 'Zoom arrière',
                onPressed: () => _pdfController.zoomLevel = (_pdfController.zoomLevel - 0.25).clamp(1.0, 3.0),
              ),
            ],
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.open_in_new_rounded),
              tooltip: 'Ouvrir en lecteur externe / Imprimer',
              onPressed: _isExporting ? null : _openExternalPdf,
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      bottomNavigationBar: _buildBottomBar(theme),
      body: _buildPdfViewer(),
    );
  }

  Widget _buildTitleBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            Text(
              'Guide Officiel Medsina',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 6),
            ContainerBadge(label: 'OFFICIEL'),
          ],
        ),
        Text(
          'Découverte des fonctionnalités • Page $_currentPage / $_pageCount',
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final totalCount = _searchResult?.totalInstanceCount ?? 0;
    final currentIndex = _searchResult?.currentInstanceIndex ?? 0;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher (ex: QCM, Urgences, Prix)...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _searchResult?.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              style: TextStyle(
                fontSize: 13,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
              onSubmitted: _executeSearch,
            ),
          ),
        ),
        const SizedBox(width: 6),
        if (_searchResult != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              totalCount > 0 ? '$currentIndex / $totalCount' : '0 trouvé',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          tooltip: 'Précédent',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => _searchResult?.previousInstance(),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          tooltip: 'Suivant',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => _searchResult?.nextInstance(),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Fermer la recherche',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: _closeSearch,
        ),
      ],
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Page navigation
            IconButton(
              icon: const Icon(Icons.first_page_rounded),
              tooltip: 'Première page',
              onPressed: _currentPage > 1 ? () => _pdfController.jumpToPage(1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Page précédente',
              onPressed: _currentPage > 1 ? () => _pdfController.previousPage() : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Page $_currentPage sur $_pageCount',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Page suivante',
              onPressed: _currentPage < _pageCount ? () => _pdfController.nextPage() : null,
            ),
            IconButton(
              icon: const Icon(Icons.last_page_rounded),
              tooltip: 'Dernière page',
              onPressed: _currentPage < _pageCount ? () => _pdfController.jumpToPage(_pageCount) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    Widget viewer = SfPdfViewer.asset(
      UserGuidePdfViewerScreen.assetPath,
      controller: _pdfController,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
      currentSearchTextHighlightColor: const Color(0xFFFFBF00).withValues(alpha: 0.85),
      otherSearchTextHighlightColor: const Color(0xFFFFFF00).withValues(alpha: 0.45),
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        setState(() {
          _pageCount = details.document.pages.count;
        });
        if (widget.initialPage != null && widget.initialPage! > 1) {
          _pdfController.jumpToPage(widget.initialPage!);
        }
        if (widget.initialSearchQuery != null && widget.initialSearchQuery!.trim().isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final q = widget.initialSearchQuery!.trim();
              _searchController.text = q;
              setState(() => _isSearching = true);
              _executeSearch(q);
            }
          });
        }
      },
      onPageChanged: (PdfPageChangedDetails details) {
        setState(() {
          _currentPage = details.newPageNumber;
        });
      },
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Erreur de chargement du PDF: ${details.description}'),
          ),
        );
      },
    );

    if (_isDarkMode) {
      viewer = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255, // red
          0, -1, 0, 0, 255, // green
          0, 0, -1, 0, 255, // blue
          0, 0, 0, 1, 0, // alpha
        ]),
        child: viewer,
      );
    }

    return viewer;
  }
}

class ContainerBadge extends StatelessWidget {
  final String label;
  const ContainerBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
