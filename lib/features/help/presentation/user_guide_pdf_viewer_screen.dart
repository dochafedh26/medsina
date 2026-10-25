import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../clinical/presentation/clinical_screen.dart';
import '../../practical_tools/presentation/practical_tools_screen.dart';
import '../../revision/presentation/revision_catalog_screen.dart';
import '../../search/presentation/global_search_screen.dart';
import '../../subscription/presentation/subscription_paywall_screen.dart';

class UserGuidePdfViewerScreen extends StatefulWidget {
  final int? initialPage;
  final String? initialSearchQuery;
  final int initialTabIndex; // 0: Interactive Guide, 1: PDF Viewer

  const UserGuidePdfViewerScreen({
    super.key,
    this.initialPage,
    this.initialSearchQuery,
    this.initialTabIndex = 1,
  });

  static const String assetPath = 'assets/data/Medsina_Guide_Decouverte_Fonctionnalites.pdf';
  static const String remotePdfUrl = 'https://medsina.medevsync.com/Medsina_Guide_Decouverte_Fonctionnalites.pdf';

  @override
  State<UserGuidePdfViewerScreen> createState() => _UserGuidePdfViewerScreenState();
}

class _UserGuidePdfViewerScreenState extends State<UserGuidePdfViewerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final PdfViewerController _pdfController = PdfViewerController();
  final TextEditingController _searchController = TextEditingController();

  Uint8List? _pdfBytes;
  bool _isLoadingPdf = true;
  String? _pdfLoadError;

  int _currentPage = 1;
  int _pageCount = 6;
  bool _isDarkMode = false;
  bool _isSearching = false;
  PdfTextSearchResult? _searchResult;
  bool _isExporting = false;

  final List<Map<String, dynamic>> _chapters = [
    {
      'page': 1,
      'title': '1. Vision, Architecture & Hors-Ligne',
      'icon': Icons.rocket_launch_rounded,
      'color': Color(0xFF0F766E),
      'desc': 'Plateforme Médicale Globale, 47 cours officiels Blida 2027, architecture locale sans connexion et mises à jour OTA transparentes.',
    },
    {
      'page': 2,
      'title': '2. Concours Résidanat & Banque de 19 000+ QCMs',
      'icon': Icons.menu_book_rounded,
      'color': Color(0xFF8B5CF6),
      'desc': 'Banque exhaustive de QCMs classés par module, examens blancs, corrections détaillées avec justifications et mode concours.',
    },
    {
      'page': 3,
      'title': '3. Pratique Clinique & Conduites à Tenir (CAT)',
      'icon': Icons.emergency_rounded,
      'color': Color(0xFFEF4444),
      'desc': 'Protocoles d\'urgences vitales, mémentos de garde de nuit, calculateurs de scores (Glasgow, Well, etc.) et normes bio.',
    },
    {
      'page': 4,
      'title': '4. IA Médicale, Vidal & Moteur Omnisearch',
      'icon': Icons.psychology_rounded,
      'color': Color(0xFF0284C7),
      'desc': 'Recherche globale unifiée dans tous les PDFs avec raccourci Ctrl+K, analyse d\'ordonnance médicamenteuse et copilote IA.',
    },
    {
      'page': 5,
      'title': '5. Formules, Tarifs & Abonnements',
      'icon': Icons.workspace_premium_rounded,
      'color': Color(0xFFF59E0B),
      'desc': 'Pass Découverte, Pass Étudiant, Résident Élite, Clinique Pro et All-Access VIP. Paiement sécurisé CIB / EDAHABIA.',
    },
    {
      'page': 6,
      'title': '6. Multiplateforme, Raccourcis & Support',
      'icon': Icons.devices_rounded,
      'color': Color(0xFF10B981),
      'desc': 'Compatibilité Android APK & Windows PC, raccourcis clavier, synchronisation multi-appareils et assistance officielle.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _loadPdfBytes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchResult?.removeListener(_onSearchUpdate);
    super.dispose();
  }

  Future<void> _loadPdfBytes() async {
    setState(() {
      _isLoadingPdf = true;
      _pdfLoadError = null;
    });

    // 1. Try RootBundle (Standard Flutter Assets)
    try {
      final byteData = await rootBundle.load(UserGuidePdfViewerScreen.assetPath);
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      if (bytes.lengthInBytes > 1000) {
        if (mounted) {
          setState(() {
            _pdfBytes = bytes;
            _isLoadingPdf = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Notice: rootBundle.load failed for user guide: $e');
    }

    // 2. Try Local File Paths (Windows Release / Working Directory fallback)
    try {
      final potentialPaths = [
        'assets/data/Medsina_Guide_Decouverte_Fonctionnalites.pdf',
        'Medsina_Guide_Decouverte_Fonctionnalites.pdf',
        'data/flutter_assets/assets/data/Medsina_Guide_Decouverte_Fonctionnalites.pdf',
        if (!kIsWeb) ...[
          '${File(Platform.resolvedExecutable).parent.path}/data/flutter_assets/assets/data/Medsina_Guide_Decouverte_Fonctionnalites.pdf',
          '${File(Platform.resolvedExecutable).parent.path}/Medsina_Guide_Decouverte_Fonctionnalites.pdf',
          r'C:\Program Files\Medsina\data\flutter_assets\assets\data\Medsina_Guide_Decouverte_Fonctionnalites.pdf',
        ]
      ];

      for (final p in potentialPaths) {
        final f = File(p);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          if (bytes.isNotEmpty) {
            if (mounted) {
              setState(() {
                _pdfBytes = bytes;
                _isLoadingPdf = false;
              });
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Notice: Local file lookup failed: $e');
    }

    // 3. Fallback: Network fetch from official Medsina Cloud
    try {
      final res = await http.get(Uri.parse(UserGuidePdfViewerScreen.remotePdfUrl));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        if (mounted) {
          setState(() {
            _pdfBytes = res.bodyBytes;
            _isLoadingPdf = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Notice: Remote PDF fetch notice: $e');
    }

    // If all fail, record error
    if (mounted) {
      setState(() {
        _isLoadingPdf = false;
        _pdfLoadError = 'Impossible de charger le document PDF sur ce poste. Vous pouvez consulter la version interactive ci-dessous ou télécharger le fichier.';
      });
    }
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
        const url = 'Medsina_Guide_Decouverte_Fonctionnalites.pdf';
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Uint8List? bytes = _pdfBytes;
        if (bytes == null) {
          final byteData = await rootBundle.load(UserGuidePdfViewerScreen.assetPath);
          bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
        }
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/Medsina_Guide_Decouverte_Fonctionnalites.pdf');
        await file.writeAsBytes(bytes, flush: true);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                      final color = item['color'] as Color;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isCurrent ? color : color.withValues(alpha: 0.12),
                          child: Icon(
                            item['icon'] as IconData,
                            size: 16,
                            color: isCurrent ? Colors.white : color,
                          ),
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? color : null,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          item['desc'] as String,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          'Page ${item['page']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? color : Colors.grey,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (_tabController.index != 1) {
                            _tabController.animateTo(1);
                          }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: _isDarkMode
          ? const Color(0xFF121212)
          : (isDark ? AppTheme.darkBackground : const Color(0xFFF1F5F9)),
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0.5,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF0F172A)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isSearching ? _buildSearchBar(isDark) : _buildTitleBar(isDark),
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Rechercher dans le document',
              onPressed: () {
                if (_tabController.index != 1) {
                  _tabController.animateTo(1);
                }
                setState(() => _isSearching = true);
              },
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal),
                    )
                  : const Icon(Icons.open_in_new_rounded),
              tooltip: 'Ouvrir en lecteur externe / Imprimer',
              onPressed: _isExporting ? null : _openExternalPdf,
            ),
            const SizedBox(width: 6),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          indicatorColor: AppTheme.primaryTeal,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.auto_stories_rounded, size: 18), text: 'Guide Découverte Interactif'),
            Tab(icon: Icon(Icons.picture_as_pdf_rounded, size: 18), text: 'Document PDF Officiel (6 P.)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Rich Interactive Guide
          _buildInteractiveGuide(isDark),

          // Tab 2: High-Fidelity PDF Viewer
          _buildPdfViewerTab(isDark),
        ],
      ),
    );
  }

  Widget _buildTitleBar(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'Documentation & Guide Medsina',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            const ContainerBadge(label: 'OFFICIEL'),
          ],
        ),
        Text(
          'Guide complet des fonctionnalités • Version 2026-2027',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    final totalCount = _searchResult?.totalInstanceCount ?? 0;
    final currentIndex = _searchResult?.currentInstanceIndex ?? 0;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher (ex: Omnisearch, QCM, Urgences, Prix)...',
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
                color: isDark ? Colors.white : Colors.black87,
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

  // --- TAB 1 : INTERACTIVE GUIDE ---

  Widget _buildInteractiveGuide(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // Welcome Header Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medsina — Plateforme Médicale Globale',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'SaaS & Révision Résidanat Blida 2027 • v1.0.16',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Bienvenue dans votre guide officiel ! Medsina regroupe l\'ensemble des 47 cours officiels, 19 000+ QCMs résidanat, conduites à tenir d\'urgences vitales, mémentos de garde et le nouveau moteur Omnisearch pour réussir vos concours et sécuriser vos gardes.',
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F766E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('Ouvrir le PDF Officiel (6 P.)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _tabController.animateTo(1),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('Tester Omnisearch (Ctrl+K)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'MODULES & FONCTIONNALITÉS CLÉS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),

        // Chapters Cards
        ..._chapters.map((ch) => _buildChapterCard(ch, isDark)),
      ],
    );
  }

  Widget _buildChapterCard(Map<String, dynamic> ch, bool isDark) {
    final page = ch['page'] as int;
    final title = ch['title'] as String;
    final desc = ch['desc'] as String;
    final icon = ch['icon'] as IconData;
    final color = ch['color'] as Color;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
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
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      Text(
                        'Page $page du Document Officiel',
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    _tabController.animateTo(1);
                    _pdfController.jumpToPage(page);
                  },
                  child: const Text('Page PDF ➔', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              desc,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            _buildChapterActionButtons(page, context),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterActionButtons(int page, BuildContext ctx) {
    switch (page) {
      case 1:
        return Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.cloud_off_rounded, size: 14),
              label: const Text('Mode Hors-Ligne'),
              onPressed: () {},
            ),
            ActionChip(
              avatar: const Icon(Icons.sync_rounded, size: 14),
              label: const Text('Mises à jour OTA'),
              onPressed: () {},
            ),
          ],
        );
      case 2:
        return Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.school_rounded, size: 14),
              label: const Text('Catalogue Résidanat'),
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const RevisionCatalogScreen()),
              ),
            ),
          ],
        );
      case 3:
        return Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.emergency_rounded, size: 14),
              label: const Text('Protocoles CAT'),
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const ClinicalScreen()),
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.handyman_rounded, size: 14),
              label: const Text('Mémentos de Garde'),
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const PracticalToolsScreen()),
              ),
            ),
          ],
        );
      case 4:
        return Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.search_rounded, size: 14),
              label: const Text('Lancer Omnisearch (Ctrl+K)'),
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
              ),
            ),
          ],
        );
      case 5:
        return Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.workspace_premium_rounded, size: 14),
              label: const Text('Voir les Tarifs & Abonnements'),
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
              ),
            ),
          ],
        );
      case 6:
      default:
        return Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.telegram, size: 14),
              label: const Text('Canal Telegram Officiel'),
              onPressed: () => launchUrl(
                Uri.parse('https://t.me/medsina_officiel'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        );
    }
  }

  // --- TAB 2 : PDF VIEWER TAB ---

  Widget _buildPdfViewerTab(bool isDark) {
    if (_isLoadingPdf) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryTeal),
            const SizedBox(height: 16),
            const Text(
              'Chargement du Guide Officiel Medsina...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Préparation de l\'affichage haute définition...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    if (_pdfBytes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 48),
              const SizedBox(height: 14),
              Text(
                _pdfLoadError ?? 'Impossible d\'afficher le lecteur PDF intégré.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadPdfBytes,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _openExternalPdf,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Lecteur externe'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget viewer = SfPdfViewer.memory(
      _pdfBytes!,
      controller: _pdfController,
      canShowScrollHead: false,
      canShowScrollStatus: false,
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
            content: Text('Erreur de lecture PDF: ${details.description}'),
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

    return Stack(
      children: [
        viewer,
        _buildFloatingPageFooter(isDark),
      ],
    );
  }

  Widget _buildFloatingPageFooter(bool isDark) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, color: Colors.white, size: 20),
                tooltip: 'Première page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _currentPage > 1 ? () => _pdfController.jumpToPage(1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                tooltip: 'Page précédente',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _currentPage > 1 ? () => _pdfController.previousPage() : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Page $_currentPage sur $_pageCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                tooltip: 'Page suivante',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _currentPage < _pageCount ? () => _pdfController.nextPage() : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, color: Colors.white, size: 20),
                tooltip: 'Dernière page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _currentPage < _pageCount ? () => _pdfController.jumpToPage(_pageCount) : null,
              ),
            ],
          ),
        ),
      ),
    );
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
