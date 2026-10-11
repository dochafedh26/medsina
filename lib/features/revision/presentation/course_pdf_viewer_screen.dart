import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/module_model.dart';

class PdfSearchOccurrence {
  final int index;
  final int pageNumber;
  final String prefix;
  final String match;
  final String suffix;

  const PdfSearchOccurrence({
    required this.index,
    required this.pageNumber,
    required this.prefix,
    required this.match,
    required this.suffix,
  });
}

class CoursePdfViewerScreen extends StatefulWidget {
  final CourseModel course;
  final String? moduleName;

  const CoursePdfViewerScreen({
    super.key,
    required this.course,
    this.moduleName,
  });

  @override
  State<CoursePdfViewerScreen> createState() => _CoursePdfViewerScreenState();
}

class _CoursePdfViewerScreenState extends State<CoursePdfViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  final Dio _dio = Dio();

  bool _isLoading = true;
  String? _errorMessage;
  double _downloadProgress = 0.0;
  Uint8List? _pdfBytes;

  int _currentPage = 1;
  int _pageCount = 0;
  bool _isDarkMode = false;

  // Search State
  bool _isSearching = false;
  bool _showResultsPanel = false;
  bool _isExtractingOccurrences = false;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;
  List<PdfSearchOccurrence> _occurrences = [];
  int _selectedOccurrenceIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPdfSecurely();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dio.close();
    super.dispose();
  }

  /// Resolve secure direct stream URL from Google Drive ID
  String _getStreamUrl() {
    final driveId = widget.course.pdfDriveId;
    if (driveId != null && driveId.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=$driveId';
    }
    final rawUrl = widget.course.pdfDownloadUrl ?? '';
    if (rawUrl.contains('/d/')) {
      final parts = rawUrl.split('/d/');
      if (parts.length > 1) {
        final id = parts[1].split('/')[0];
        return 'https://drive.google.com/uc?export=download&id=$id';
      }
    }
    return rawUrl;
  }

  Future<void> _loadPdfSecurely() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
    });

    try {
      final streamUrl = _getStreamUrl();
      if (streamUrl.isEmpty) {
        throw Exception('Support PDF non disponible pour ce cours.');
      }

      // Check local private app cache first for instant repeat opening
      final dir = await getApplicationSupportDirectory();
      final cacheDir = Directory('${dir.path}/medsina_secure_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cacheFile = File('${cacheDir.path}/c_${widget.course.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.dat');

      if (await cacheFile.exists() && await cacheFile.length() > 1024) {
        final bytes = await cacheFile.readAsBytes();
        if (mounted) {
          setState(() {
            _pdfBytes = bytes;
            _isLoading = false;
          });
        }
        return;
      }

      // Download bytes privately into sandbox cache
      final response = await _dio.get<List<int>>(
        streamUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      final bytes = Uint8List.fromList(response.data!);
      await cacheFile.writeAsBytes(bytes);

      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Impossible de charger le document sécurisé.\n(${e.toString().replaceAll(RegExp(r'https?://[^\s]+'), '...')})';
        });
      }
    }
  }

  void _executeSearch(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    // 1. Trigger Syncfusion built-in viewer search
    _searchResult?.clear();
    _searchResult = _pdfController.searchText(cleanQuery);
    _searchResult?.addListener(_onSearchResultUpdated);

    // 2. Extract detailed occurrences with page numbers and text snippets
    _extractSearchOccurrences(cleanQuery);

    setState(() {
      _showResultsPanel = true;
    });
  }

  void _onSearchResultUpdated() {
    if (mounted) {
      setState(() {
        if (_searchResult != null && _searchResult!.hasResult) {
          _selectedOccurrenceIndex = (_searchResult!.currentInstanceIndex - 1).clamp(0, _occurrences.isEmpty ? 0 : _occurrences.length - 1);
        }
      });
    }
  }

  Future<void> _extractSearchOccurrences(String query) async {
    if (_pdfBytes == null) return;

    setState(() {
      _isExtractingOccurrences = true;
      _occurrences = [];
    });

    try {
      final doc = p.PdfDocument(inputBytes: _pdfBytes!);
      final extractor = p.PdfTextExtractor(doc);
      final List<PdfSearchOccurrence> results = [];
      final lowerQuery = query.toLowerCase();
      int occurrenceCounter = 0;

      for (int pageIdx = 0; pageIdx < doc.pages.count; pageIdx++) {
        final pageText = extractor.extractText(startPageIndex: pageIdx, endPageIndex: pageIdx);
        if (pageText.isEmpty) continue;

        final lowerText = pageText.toLowerCase();
        int startIndex = 0;

        while (true) {
          final foundIdx = lowerText.indexOf(lowerQuery, startIndex);
          if (foundIdx == -1) break;

          final matchEnd = foundIdx + query.length;
          final prefixStart = (foundIdx - 35).clamp(0, pageText.length);
          final suffixEnd = (matchEnd + 45).clamp(0, pageText.length);

          final prefix = pageText.substring(prefixStart, foundIdx).replaceAll('\n', ' ').trimLeft();
          final match = pageText.substring(foundIdx, matchEnd);
          final suffix = pageText.substring(matchEnd, suffixEnd).replaceAll('\n', ' ').trimRight();

          occurrenceCounter++;
          results.add(PdfSearchOccurrence(
            index: occurrenceCounter,
            pageNumber: pageIdx + 1,
            prefix: prefix.isEmpty ? '' : '...$prefix',
            match: match,
            suffix: suffix.isEmpty ? '' : '$suffix...',
          ));

          startIndex = matchEnd;
        }
      }

      doc.dispose();

      if (mounted) {
        setState(() {
          _occurrences = results;
          _isExtractingOccurrences = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isExtractingOccurrences = false;
        });
      }
    }
  }

  void _jumpToOccurrence(int index, PdfSearchOccurrence occ) {
    setState(() {
      _selectedOccurrenceIndex = index;
    });

    // Jump to the target page in the PDF viewer
    _pdfController.jumpToPage(occ.pageNumber);

    // Sync instance in Syncfusion controller
    if (_searchResult != null && _searchResult!.hasResult) {
      final targetInstance = index + 1;
      final currentInstance = _searchResult!.currentInstanceIndex;
      final diff = targetInstance - currentInstance;

      if (diff > 0) {
        for (int i = 0; i < diff; i++) {
          _searchResult!.nextInstance();
        }
      } else if (diff < 0) {
        for (int i = 0; i < diff.abs(); i++) {
          _searchResult!.previousInstance();
        }
      }
    }
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _showResultsPanel = false;
      _searchResult?.clear();
      _searchController.clear();
      _occurrences = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: _isDarkMode ? Colors.white : Colors.black87,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isSearching ? _buildSearchBar() : _buildTitle(),
        actions: [
          if (!_isLoading && _pdfBytes != null) ...[
            if (!_isSearching)
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Rechercher dans le cours',
                onPressed: () => setState(() => _isSearching = true),
              ),
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              tooltip: _isDarkMode ? 'Mode Clair' : 'Mode Nuit',
              onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in_rounded),
              tooltip: 'Zoom avant',
              onPressed: () => _pdfController.zoomLevel = (_pdfController.zoomLevel + 0.25).clamp(1.0, 3.5),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out_rounded),
              tooltip: 'Zoom arrière',
              onPressed: () => _pdfController.zoomLevel = (_pdfController.zoomLevel - 0.25).clamp(1.0, 3.5),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (!_isLoading && _pdfBytes != null) _buildPageFooter(),
          if (_isSearching && _showResultsPanel) _buildResultsSidePanel(),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.course.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.moduleName != null)
          Text(
            widget.moduleName!,
            style: const TextStyle(fontSize: 11, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final totalCount = _searchResult?.totalInstanceCount ?? 0;
    final currentIndex = _searchResult?.currentInstanceIndex ?? 0;
    final isSearchingText = _searchResult != null && !_searchResult!.isSearchCompleted && totalCount == 0;

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
                hintText: 'Rechercher un mot médical...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _searchResult?.clear();
                          setState(() {
                            _occurrences = [];
                          });
                        },
                      )
                    : null,
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: _executeSearch,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Occurrences badge
        if (_searchResult != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isSearchingText
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal),
                  )
                : Text(
                    totalCount > 0 ? '$currentIndex / $totalCount' : '0 trouvé',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                  ),
          ),
        // Previous instance
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          tooltip: 'Précédent',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => _searchResult?.previousInstance(),
        ),
        // Next instance
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          tooltip: 'Suivant',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => _searchResult?.nextInstance(),
        ),
        // Toggle occurrences list panel
        IconButton(
          icon: Icon(
            _showResultsPanel ? Icons.format_list_bulleted_rounded : Icons.list_alt_rounded,
            color: _showResultsPanel ? AppTheme.primaryTeal : null,
          ),
          tooltip: 'Afficher la liste des occurrences',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => setState(() => _showResultsPanel = !_showResultsPanel),
        ),
        // Close search
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

  Widget _buildResultsSidePanel() {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width > 600 ? 360 : MediaQuery.of(context).size.width * 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(-3, 0)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.manage_search_rounded, color: AppTheme.primaryTeal, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Occurrences trouvées',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          _occurrences.isNotEmpty
                              ? '${_occurrences.length} résultats pour "${_searchController.text.trim()}"'
                              : 'Recherche en cours...',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _showResultsPanel = false),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isExtractingOccurrences
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primaryTeal),
                          SizedBox(height: 12),
                          Text('Analyse des pages du cours...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    )
                  : _occurrences.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                Text(
                                  'Aucun résultat pour "${_searchController.text.trim()}"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _occurrences.length,
                          separatorBuilder: (_, index) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
                          itemBuilder: (context, index) {
                            final occ = _occurrences[index];
                            final isSelected = index == _selectedOccurrenceIndex;

                            return InkWell(
                              onTap: () => _jumpToOccurrence(index, occ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                color: isSelected
                                    ? AppTheme.primaryTeal.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppTheme.primaryTeal : Colors.grey.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'P. ${occ.pageNumber}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.4,
                                            color: _isDarkMode ? Colors.white70 : const Color(0xFF334155),
                                          ),
                                          children: [
                                            TextSpan(text: occ.prefix),
                                            TextSpan(
                                              text: ' ${occ.match} ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? const Color(0xFFD97706) : AppTheme.primaryTeal,
                                                backgroundColor: const Color(0xFFFEF3C7),
                                              ),
                                            ),
                                            TextSpan(text: occ.suffix),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryTeal),
            const SizedBox(height: 16),
            const Text(
              'Ouverture sécurisée du document...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            if (_downloadProgress > 0)
              Text(
                'Chargement : ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 14, color: Color(0xFF2563EB)),
                  SizedBox(width: 6),
                  Text(
                    'Lecture protégée dans Medsina',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPdfSecurely,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                ),
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
      },
      onPageChanged: (PdfPageChangedDetails details) {
        setState(() {
          _currentPage = details.newPageNumber;
        });
      },
    );

    // Dark mode invert filter
    if (_isDarkMode) {
      viewer = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1.0, 0.0, 0.0, 0.0, 255.0, // R
          0.0, -1.0, 0.0, 0.0, 255.0, // G
          0.0, 0.0, -1.0, 0.0, 255.0, // B
          0.0, 0.0, 0.0, 1.0, 0.0,    // A
        ]),
        child: viewer,
      );
    }

    return viewer;
  }

  Widget _buildPageFooter() {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            '$_currentPage / $_pageCount',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
