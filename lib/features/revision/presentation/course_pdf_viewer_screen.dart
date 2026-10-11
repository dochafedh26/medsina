import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/course_model.dart';

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
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;

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
            IconButton(
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
              tooltip: _isSearching ? 'Fermer la recherche' : 'Rechercher dans le cours',
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchResult?.clear();
                    _searchController.clear();
                  }
                });
              },
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
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: 'Rechercher un terme médical...',
        border: InputBorder.none,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      style: const TextStyle(fontSize: 14),
      onSubmitted: (query) {
        if (query.trim().isNotEmpty) {
          _searchResult = _pdfController.searchText(query.trim());
          _searchResult?.addListener(() {
            if (mounted) setState(() {});
          });
        }
      },
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
