import '../../comments/presentation/medical_comments_sheet.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/services/recent_activity_service.dart';
import '../../../core/services/user_study_progress_service.dart';
import '../models/module_model.dart';
import '../services/offline_course_manager.dart';
import '../services/user_qcm_annotation_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';
import 'course_summary_screen.dart';
import 'qcm_study_screen.dart';

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
  final String? initialSearchQuery;
  final String? customPdfUrl;
  final String? customTitle;
  final bool isBooklet;

  const CoursePdfViewerScreen({
    super.key,
    required this.course,
    this.moduleName,
    this.initialSearchQuery,
    this.customPdfUrl,
    this.customTitle,
    this.isBooklet = false,
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

  bool _hasShownCompletionPrompt = false;
  final UserStudyProgressService _progressService = UserStudyProgressService.instance;
  final UserQcmAnnotationService _annService = UserQcmAnnotationService.instance;

  bool get _isCourseValidated {
    final inProfile = _progressService.progress.completedCourseIds.contains(widget.course.id);
    final inPlanner = _annService.getPlannerEntry(widget.course.id, moduleId: widget.course.moduleId).layer1Done;
    return inProfile || inPlanner;
  }

  @override
  void initState() {
    super.initState();
    _loadPdfSecurely();
    RecentActivityService.instance.recordCourseView(
      course: widget.course,
      moduleName: widget.moduleName,
    );
    _progressService.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _annService.ensureInitialized().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dio.close();
    super.dispose();
  }

  String get _cacheKey {
    if (widget.isBooklet) {
      return '${widget.course.id}_livret_2027';
    }
    if (widget.customPdfUrl != null && widget.customPdfUrl!.isNotEmpty) {
      return '${widget.course.id}_custom_${widget.customPdfUrl.hashCode.abs()}';
    }
    return widget.course.id;
  }

  String _normalizeRemotePdfUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.contains('/d/')) {
      final parts = trimmed.split('/d/');
      if (parts.length > 1) {
        final id = parts[1].split('/')[0].split('?')[0];
        if (id.isNotEmpty) {
          return 'https://drive.google.com/uc?export=download&id=$id';
        }
      }
    }
    if (trimmed.contains('drive.google.com/open?id=')) {
      final uri = Uri.tryParse(trimmed);
      final id = uri?.queryParameters['id'];
      if (id != null && id.isNotEmpty) {
        return 'https://drive.google.com/uc?export=download&id=$id';
      }
    }
    return trimmed;
  }

  bool _hasValidPdfHeader(Uint8List bytes) {
    if (bytes.length < 5) return false;
    final limit = bytes.length < 1024 ? bytes.length - 4 : 1020;
    for (int i = 0; i <= limit; i++) {
      if (bytes[i] == 0x25 && // %
          bytes[i + 1] == 0x50 && // P
          bytes[i + 2] == 0x44 && // D
          bytes[i + 3] == 0x46) {
        // F
        return true;
      }
    }
    return false;
  }

  /// Resolve secure direct stream URL from Google Drive ID or Supabase Storage
  String _getStreamUrl() {
    if (widget.customPdfUrl != null && widget.customPdfUrl!.isNotEmpty) {
      return _normalizeRemotePdfUrl(widget.customPdfUrl!);
    }
    if (widget.isBooklet &&
        widget.course.bundlePdfUrl != null &&
        widget.course.bundlePdfUrl!.isNotEmpty) {
      return _normalizeRemotePdfUrl(widget.course.bundlePdfUrl!);
    }
    final driveId = widget.course.pdfDriveId;
    if (driveId != null && driveId.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=$driveId';
    }
    final rawUrl = widget.course.pdfDownloadUrl ?? '';
    return _normalizeRemotePdfUrl(rawUrl);
  }

  Future<void> _loadPdfSecurely() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
    });

    try {
      // Clean up any legacy corrupted cache on the base course ID if it holds HTML instead of PDF
      if (widget.isBooklet) {
        try {
          final legacyFile = await OfflineCourseManager.instance.getCourseFile(
            widget.course.id,
          );
          if (await legacyFile.exists() && await legacyFile.length() > 0) {
            final legacyBytes = await legacyFile.readAsBytes();
            if (!_hasValidPdfHeader(legacyBytes)) {
              await legacyFile.delete();
            }
          }
        } catch (_) {}
      }

      // 1. Check if course/booklet is already available offline in local sandbox
      final cacheFile = await OfflineCourseManager.instance.getCourseFile(
        _cacheKey,
      );
      if (await cacheFile.exists() && await cacheFile.length() > 1024) {
        final bytes = await cacheFile.readAsBytes();
        if (_hasValidPdfHeader(bytes)) {
          if (mounted) {
            setState(() {
              _pdfBytes = bytes;
              _isLoading = false;
            });
          }
          return;
        } else {
          // Corrupted or HTML file in cache — delete and re-download
          try {
            await cacheFile.delete();
          } catch (_) {}
        }
      }

      // 2. Check if the course is an in-app asset (only when not opening a remote booklet)
      final rawDownloadUrl = widget.isBooklet
          ? (widget.course.bundlePdfUrl ?? '')
          : (widget.course.pdfDownloadUrl ?? '');
      if (rawDownloadUrl.startsWith('assets/') ||
          rawDownloadUrl.startsWith('packages/')) {
        try {
          final byteData = await rootBundle.load(rawDownloadUrl);
          final bytes = byteData.buffer.asUint8List();
          if (_hasValidPdfHeader(bytes)) {
            try {
              if (!await cacheFile.parent.exists()) {
                await cacheFile.parent.create(recursive: true);
              }
              await cacheFile.writeAsBytes(bytes);
            } catch (_) {}

            if (mounted) {
              setState(() {
                _pdfBytes = bytes;
                _isLoading = false;
              });
            }
            return;
          }
        } catch (assetErr) {
          debugPrint(
            'Notice: unable to load asset "$rawDownloadUrl", falling back to network: $assetErr',
          );
        }
      }

      // 3. Check if it is a local filesystem path on device
      if (!rawDownloadUrl.startsWith('http://') &&
          !rawDownloadUrl.startsWith('https://') &&
          rawDownloadUrl.isNotEmpty) {
        final localFile = File(rawDownloadUrl);
        if (await localFile.exists()) {
          final bytes = await localFile.readAsBytes();
          if (_hasValidPdfHeader(bytes)) {
            if (mounted) {
              setState(() {
                _pdfBytes = bytes;
                _isLoading = false;
              });
            }
            return;
          }
        }
      }

      // 4. Fall back to secure remote streaming via Supabase Storage, Google Drive, or HTTP
      final streamUrl = _getStreamUrl();
      if (streamUrl.isEmpty ||
          (!streamUrl.startsWith('http://') &&
              !streamUrl.startsWith('https://'))) {
        throw Exception('Support PDF non disponible pour ce cours.');
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
      if (!_hasValidPdfHeader(bytes)) {
        throw Exception(
          'Le fichier téléchargé n\'est pas un document PDF valide.',
        );
      }

      if (!await cacheFile.parent.exists()) {
        await cacheFile.parent.create(recursive: true);
      }
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
          _errorMessage =
              'Impossible de charger le document sécurisé.\n(${e.toString().replaceAll(RegExp(r'https?://[^\s]+'), '...')})';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

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
          AnimatedBuilder(
            animation: OfflineCourseManager.instance,
            builder: (context, _) {
              final isOffline = OfflineCourseManager.instance.isCourseAvailableOfflineSync(_cacheKey);
              if (isOffline) {
                return Tooltip(
                  message: 'Cours enregistré en local (100% accessible hors-ligne)',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.offline_pin_rounded, color: Colors.green, size: 20),
                        if (isDesktop) ...[
                          const SizedBox(width: 4),
                          const Text(
                            'Hors-ligne',
                            style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }
              return Tooltip(
                message: 'Télécharger pour révision hors-ligne',
                child: IconButton(
                  icon: const Icon(Icons.download_for_offline_rounded, color: AppTheme.primaryTeal),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Enregistrement de "${widget.course.name}" pour le mode hors-ligne...'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    final ok = await OfflineCourseManager.instance.downloadCourse(widget.course);
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cours enregistré pour consultation hors-ligne !'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.forum_outlined, color: AppTheme.primaryTeal),
            tooltip: 'Commentaires & Notes du Cours',
            onPressed: () {
              MedicalCommentsSheet.show(
                context,
                targetType: 'course',
                targetId: widget.course.id,
                targetTitle: widget.course.name,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.summarize_rounded, color: AppTheme.primaryTeal),
            tooltip: 'Fiche Synthétique du Cours',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CourseSummaryScreen(
                    course: widget.course,
                    moduleName: widget.moduleName,
                  ),
                ),
              );
            },
          ),
          // Validation du cours (Couche 1 / Profil)
          AnimatedBuilder(
            animation: Listenable.merge([_progressService.progressNotifier, _annService]),
            builder: (context, _) {
              final isValidated = _isCourseValidated;
              if (screenWidth >= 620) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: isValidated
                      ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                          label: const Text('Validé ✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: _showCourseCompletionOptions,
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: const Text('Valider le cours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: _validateCourseCompletion,
                        ),
                );
              }
              return IconButton(
                icon: Icon(
                  isValidated ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                  color: isValidated ? const Color(0xFF10B981) : AppTheme.primaryTeal,
                ),
                tooltip: isValidated ? 'Cours validé ✓' : 'Valider ce cours (+30 XP)',
                onPressed: isValidated ? _showCourseCompletionOptions : _validateCourseCompletion,
              );
            },
          ),
          if (!_isLoading && _pdfBytes != null) ...[
            if (!_isSearching)
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Rechercher dans le cours',
                onPressed: () => setState(() => _isSearching = true),
              ),
            if (screenWidth >= 500)
              IconButton(
                icon: Icon(_isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                tooltip: _isDarkMode ? 'Mode Clair' : 'Mode Nuit',
                onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
              ),
            if (isDesktop) ...[
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
            if (screenWidth < 500)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Plus d\'options',
                onSelected: (val) {
                  if (val == 'theme') {
                    setState(() => _isDarkMode = !_isDarkMode);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'theme',
                    child: Row(
                      children: [
                        Icon(
                          _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          size: 20,
                          color: _isDarkMode ? Colors.amber : const Color(0xFF0F172A),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isDarkMode ? 'Passer en Mode Clair' : 'Passer en Mode Nuit',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
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
    final titleText = widget.customTitle ??
        (widget.isBooklet
            ? '🔥 Livret Résidanat 2027 • ${widget.course.name}'
            : widget.course.name);
    final subtitleText = widget.isBooklet
        ? 'Livret Tout-en-Un (Synthèse + Cours + QCMs + Corrigé type)'
        : (widget.moduleName ?? 'Support de Révision');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titleText,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitleText,
          style: TextStyle(
            fontSize: 11,
            color: widget.isBooklet ? const Color(0xFFD97706) : AppTheme.primaryTeal,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
        if (_pageCount > 0 && details.newPageNumber == _pageCount && !_hasShownCompletionPrompt) {
          _hasShownCompletionPrompt = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showEndOfCourseCelebration();
            }
          });
        }
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
        child: AnimatedBuilder(
          animation: Listenable.merge([_progressService.progressNotifier, _annService]),
          builder: (context, _) {
            final isValidated = _isCourseValidated;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_currentPage / $_pageCount',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 14, color: Colors.white24),
                  const SizedBox(width: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isValidated ? _showCourseCompletionOptions : _validateCourseCompletion,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isValidated ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                            size: 15,
                            color: isValidated ? const Color(0xFF34D399) : Colors.white70,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isValidated ? 'Validé ✓' : 'Valider (+30 XP)',
                            style: TextStyle(
                              color: isValidated ? const Color(0xFF34D399) : Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _validateCourseCompletion() async {
    // 1. Enregistrement dans UserStudyProgressService (+30 XP, total, streak/daily goals)
    await _progressService.markCourseCompleted(
      widget.course.id,
      courseTitle: widget.course.name,
      module: widget.moduleName,
    );

    // 2. Validation de la Couche 1 dans le Study Planner (UserQcmAnnotationService)
    final plannerEntry = _annService.getPlannerEntry(widget.course.id, moduleId: widget.course.moduleId);
    if (!plannerEntry.layer1Done) {
      await _annService.togglePlannerLayer(
        courseId: widget.course.id,
        moduleId: widget.course.moduleId,
        layerIndex: 1,
      );
    }

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('🎉 Cours "${widget.course.name}" validé ! (+30 XP)'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: widget.course.questionsCount > 0
              ? SnackBarAction(
                  label: 'QCM ➔',
                  textColor: Colors.amber,
                  onPressed: _startCourseQcm,
                )
              : null,
        ),
      );
    }
  }

  Future<void> _unvalidateCourse() async {
    await _progressService.toggleCourseCompleted(
      widget.course.id,
      courseTitle: widget.course.name,
    );
    final plannerEntry = _annService.getPlannerEntry(widget.course.id, moduleId: widget.course.moduleId);
    if (plannerEntry.layer1Done) {
      await _annService.togglePlannerLayer(
        courseId: widget.course.id,
        moduleId: widget.course.moduleId,
        layerIndex: 1,
      );
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Validation du cours annulée.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startCourseQcm() {
    final isStudent = context.read<AuthBloc>().state.user?.isStudent == true;
    context.read<RevisionBloc>().add(
          OpenCourseQuestionsEvent(widget.course, resume: false, filterForStudent: isStudent),
        );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QcmStudyScreen()),
    );
  }

  void _showEndOfCourseCelebration() {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isValidated = _isCourseValidated;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryTeal, Color(0xFF0284C7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fin de Lecture du Support ! 🎉',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.course.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isValidated
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isValidated ? const Color(0xFF10B981) : AppTheme.primaryTeal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isValidated ? Icons.check_circle_rounded : Icons.star_rounded,
                        color: isValidated ? const Color(0xFF10B981) : const Color(0xFFD97706),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isValidated
                              ? 'Ce cours est déjà validé (Couche 1 enregistrée dans le Study Planner et votre Profil).'
                              : 'Validez votre lecture pour enregistrer la Couche 1 dans le Study Planner et remporter +30 XP !',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isValidated ? const Color(0xFF047857) : const Color(0xFF0F766E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!isValidated) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        'Valider la Lecture du Cours (+30 XP)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _validateCourseCompletion();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                        ),
                        icon: const Icon(Icons.menu_book_rounded, color: Color(0xFF8B5CF6), size: 16),
                        label: const Text(
                          'Fiche Synthèse',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CourseSummaryScreen(
                                course: widget.course,
                                moduleName: widget.moduleName,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (widget.course.questionsCount > 0) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                          label: Text(
                            'QCM (${widget.course.questionsCount})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _startCourseQcm();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCourseCompletionOptions() {
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
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cours Validé ✓',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.course.name,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'La Couche 1 (Lecture) est validée dans votre Study Planner et comptabilisée dans votre Profil (+30 XP).',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (widget.course.questionsCount > 0)
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tileColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF0FDF4),
                    leading: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryTeal),
                    title: const Text('Passer aux QCMs de ce cours', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startCourseQcm();
                    },
                  ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: const Icon(Icons.undo_rounded, color: Colors.redAccent),
                  title: const Text('Annuler la validation de ce cours', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _unvalidateCourse();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
