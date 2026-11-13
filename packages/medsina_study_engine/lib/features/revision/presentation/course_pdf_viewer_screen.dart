import '../../comments/presentation/medical_comments_sheet.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:medsina_core/core/theme/app_theme.dart';
import 'package:medsina_core/core/services/recent_activity_service.dart';
import 'package:medsina_core/core/services/user_study_progress_service.dart';
import '../models/module_model.dart';
import '../services/offline_course_manager.dart';
import '../services/user_qcm_annotation_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medsina_core/features/auth/bloc/auth_bloc.dart';
import '../bloc/revision_bloc.dart';
import '../bloc/revision_event.dart';
import '../models/pdf_annotation_model.dart';
import '../services/pdf_annotation_service.dart';
import 'package:medsina_core/core/interfaces/feature_contracts.dart';
import 'qcm_study_screen.dart';

enum ReadingComfortMode { day, sepia, night }
enum AnnotationToolMode { none, highlighter, stickyNote, pen }

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
  ReadingComfortMode _readingComfortMode = ReadingComfortMode.day;
  bool _isSinglePageLayout = false;
  bool _showAnnotationToolbar = true;
  AnnotationToolMode _currentToolMode = AnnotationToolMode.none;
  String _selectedColorHex = '#FACC15';
  List<PdfDrawingPoint> _currentStroke = [];
  final PdfAnnotationService _annotationService = PdfAnnotationService.instance;

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
    _annotationService.ensureInitialized().then((_) {
      _annotationService.getAnnotations(_cacheKey).then((_) {
        if (mounted) setState(() {});
      });
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
          return 'https://drive.usercontent.google.com/download?id=$id&export=download&confirm=t';
        }
      }
    }
    if (trimmed.contains('drive.google.com/open?id=')) {
      final uri = Uri.tryParse(trimmed);
      final id = uri?.queryParameters['id'];
      if (id != null && id.isNotEmpty) {
        return 'https://drive.usercontent.google.com/download?id=$id&export=download&confirm=t';
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
      return 'https://drive.usercontent.google.com/download?id=$driveId&export=download&confirm=t';
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
      final rawDownloadUrl = widget.customPdfUrl != null &&
              widget.customPdfUrl!.isNotEmpty
          ? widget.customPdfUrl!
          : (widget.isBooklet
              ? (widget.course.bundlePdfUrl ?? '')
              : (widget.course.pdfDownloadUrl ?? ''));
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
              MedsinaFeatureRegistry.instance.dispatchRoute(context, 'course_summary', {'course': widget.course, 'moduleName': widget.moduleName});
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
            IconButton(
              icon: Icon(
                _showAnnotationToolbar ? Icons.draw_rounded : Icons.edit_off_rounded,
                color: _showAnnotationToolbar ? AppTheme.primaryTeal : null,
              ),
              tooltip: _showAnnotationToolbar ? 'Masquer la barre Acrobat' : 'Afficher la barre Acrobat',
              onPressed: () => setState(() => _showAnnotationToolbar = !_showAnnotationToolbar),
            ),
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
                onPressed: () {
                  setState(() {
                    _isDarkMode = !_isDarkMode;
                    _readingComfortMode = _isDarkMode ? ReadingComfortMode.night : ReadingComfortMode.day;
                  });
                },
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
                    setState(() {
                      _isDarkMode = !_isDarkMode;
                      _readingComfortMode = _isDarkMode ? ReadingComfortMode.night : ReadingComfortMode.day;
                    });
                  } else if (val == 'comfort') {
                    _showReadingComfortModal();
                  } else if (val == 'jump') {
                    _showJumpToPageDialog();
                  } else if (val == 'notes') {
                    _showCourseNotesList();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'comfort',
                    child: const Row(
                      children: [
                        Icon(Icons.auto_stories_rounded, size: 20, color: AppTheme.primaryTeal),
                        SizedBox(width: 12),
                        Text('Confort de Lecture (Sépia/Nuit)', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'jump',
                    child: const Row(
                      children: [
                        Icon(Icons.tag_rounded, size: 20, color: AppTheme.primaryTeal),
                        SizedBox(width: 12),
                        Text('Aller à la page...', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'notes',
                    child: const Row(
                      children: [
                        Icon(Icons.sticky_note_2_rounded, size: 20, color: Color(0xFFCA8A04)),
                        SizedBox(width: 12),
                        Text('Notes & Post-Its du Cours', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
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
          if (!_isLoading && _pdfBytes != null) _buildAnnotationOverlay(),
          if (!_isLoading && _pdfBytes != null && _showAnnotationToolbar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildAcrobatToolbar(),
            ),
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
      enableDoubleTapZooming: _currentToolMode == AnnotationToolMode.none,
      pageLayoutMode: _isSinglePageLayout ? PdfPageLayoutMode.single : PdfPageLayoutMode.continuous,
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

    // Reading Comfort Filter (Night OLED, Sepia warm paper, or Day normal)
    if (_readingComfortMode == ReadingComfortMode.night || _isDarkMode) {
      viewer = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1.0, 0.0, 0.0, 0.0, 255.0, // R
          0.0, -1.0, 0.0, 0.0, 255.0, // G
          0.0, 0.0, -1.0, 0.0, 255.0, // B
          0.0, 0.0, 0.0, 1.0, 0.0,    // A
        ]),
        child: viewer,
      );
    } else if (_readingComfortMode == ReadingComfortMode.sepia) {
      viewer = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.94, 0.05, 0.0, 0.0, 15.0,
          0.05, 0.89, 0.0, 0.0, 10.0,
          0.0, 0.05, 0.76, 0.0, -5.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
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
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _showJumpToPageDialog,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tag_rounded, size: 13, color: Colors.white70),
                          const SizedBox(width: 3),
                          Text(
                            '$_currentPage / $_pageCount',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
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
                          MedsinaFeatureRegistry.instance.dispatchRoute(context, 'course_summary', {'course': widget.course, 'moduleName': widget.moduleName});
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

  // --- ACROBAT / FOXIT READER ADVANCED SUITE ---

  Widget _buildAcrobatToolbar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notesCount = _annotationService.getNotesForCourse(_cacheKey).length;
    final colors = ['#FACC15', '#22C55E', '#38BDF8', '#F43F5E', '#FB923C'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.95) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolModeButton(
              mode: AnnotationToolMode.none,
              icon: Icons.pan_tool_rounded,
              label: 'Nav',
              tooltip: 'Navigation & Zoom (pan)',
            ),
            _toolModeButton(
              mode: AnnotationToolMode.pen,
              icon: Icons.edit_rounded,
              label: 'Stylet',
              tooltip: 'Dessin libre & schémas',
            ),
            _toolModeButton(
              mode: AnnotationToolMode.highlighter,
              icon: Icons.brush_rounded,
              label: 'Surligneur',
              tooltip: 'Surlignage fluorescent',
            ),
            _toolModeButton(
              mode: AnnotationToolMode.stickyNote,
              icon: Icons.note_alt_rounded,
              label: 'Post-It',
              tooltip: 'Ajouter un post-it médical',
            ),

            if (_currentToolMode == AnnotationToolMode.pen ||
                _currentToolMode == AnnotationToolMode.highlighter) ...[
              Container(
                height: 20,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: isDark ? Colors.white24 : Colors.black12,
              ),
              ...colors.map((c) {
                final isSelected = _selectedColorHex == c;
                final col = _DrawingPainter.parseHex(c);
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorHex = c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isSelected ? 22 : 18,
                    height: isSelected ? 22 : 18,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: col.withOpacity(0.6), blurRadius: 6)]
                          : null,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.undo_rounded, size: 18),
                tooltip: 'Annuler la dernière annotation',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () async {
                  final list = _annotationService.getAnnotationsForPage(_cacheKey, _currentPage);
                  if (list.isNotEmpty) {
                    await _annotationService.removeAnnotation(_cacheKey, list.last.id);
                    if (mounted) setState(() {});
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
                tooltip: 'Effacer la page actuelle',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () async {
                  await _annotationService.clearPageAnnotations(_cacheKey, _currentPage);
                  if (mounted) setState(() {});
                },
              ),
            ],

            Container(
              height: 20,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: isDark ? Colors.white24 : Colors.black12,
            ),

            IconButton(
              icon: Icon(
                _readingComfortMode == ReadingComfortMode.sepia
                    ? Icons.auto_stories_rounded
                    : (_readingComfortMode == ReadingComfortMode.night
                        ? Icons.nightlight_round
                        : Icons.wb_sunny_rounded),
                size: 19,
                color: _readingComfortMode == ReadingComfortMode.sepia
                    ? const Color(0xFFD97706)
                    : (_readingComfortMode == ReadingComfortMode.night
                        ? const Color(0xFF8B5CF6)
                        : null),
              ),
              tooltip: 'Modes de confort de lecture (Jour, Sépia, Nuit)',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _showReadingComfortModal,
            ),

            IconButton(
              icon: const Icon(Icons.tag_rounded, size: 19),
              tooltip: 'Aller directement à une page',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _showJumpToPageDialog,
            ),

            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.sticky_note_2_outlined, size: 19),
                  tooltip: 'Liste des Post-Its du cours',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: _showCourseNotesList,
                ),
                if (notesCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFCA8A04),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$notesCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            IconButton(
              icon: const Icon(Icons.bookmarks_rounded, size: 19),
              tooltip: 'Sommaire & Signets',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _showBookmarksSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolModeButton({
    required AnnotationToolMode mode,
    required IconData icon,
    required String label,
    required String tooltip,
  }) {
    final isSelected = _currentToolMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _currentToolMode = mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : null,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnotationOverlay() {
    final pageAnnotations = _annotationService.getAnnotationsForPage(_cacheKey, _currentPage);
    final notes = pageAnnotations.where((a) => a.type == PdfAnnotationType.note).toList();

    return Stack(
      children: [
        Positioned.fill(
          child: _currentToolMode == AnnotationToolMode.pen ||
                  _currentToolMode == AnnotationToolMode.highlighter
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    setState(() {
                      _currentStroke = [
                        PdfDrawingPoint(details.localPosition.dx, details.localPosition.dy)
                      ];
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _currentStroke.add(
                        PdfDrawingPoint(details.localPosition.dx, details.localPosition.dy)
                      );
                    });
                  },
                  onPanEnd: (details) async {
                    if (_currentStroke.length >= 2) {
                      final annotation = PdfAnnotationModel(
                        id: 'ann_${DateTime.now().millisecondsSinceEpoch}',
                        courseId: _cacheKey,
                        pageNumber: _currentPage,
                        type: _currentToolMode == AnnotationToolMode.highlighter
                            ? PdfAnnotationType.highlight
                            : PdfAnnotationType.drawing,
                        colorHex: _selectedColorHex,
                        points: List.from(_currentStroke),
                        strokeWidth: _currentToolMode == AnnotationToolMode.highlighter ? 18.0 : 3.5,
                        createdAt: DateTime.now(),
                      );
                      await _annotationService.addAnnotation(annotation);
                      setState(() {
                        _currentStroke = [];
                      });
                    }
                  },
                  child: CustomPaint(
                    painter: _DrawingPainter(
                      savedAnnotations: pageAnnotations,
                      activeStroke: _currentStroke,
                      activeColor: _DrawingPainter.parseHex(_selectedColorHex),
                    ),
                  ),
                )
              : _currentToolMode == AnnotationToolMode.stickyNote
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        _promptAddStickyNote(details.localPosition.dx, details.localPosition.dy);
                      },
                      child: CustomPaint(
                        painter: _DrawingPainter(
                          savedAnnotations: pageAnnotations,
                          activeStroke: const [],
                          activeColor: Colors.transparent,
                        ),
                      ),
                    )
                  : IgnorePointer(
                      child: CustomPaint(
                        painter: _DrawingPainter(
                          savedAnnotations: pageAnnotations,
                          activeStroke: const [],
                          activeColor: Colors.transparent,
                        ),
                      ),
                    ),
        ),

        ...notes.map((note) {
          final pt = note.points.isNotEmpty ? note.points.first : const PdfDrawingPoint(20, 80);
          return Positioned(
            left: pt.x.clamp(8.0, (MediaQuery.of(context).size.width - 140).clamp(8.0, 1000.0)),
            top: pt.y.clamp(60.0, (MediaQuery.of(context).size.height - 120).clamp(60.0, 1500.0)),
            child: GestureDetector(
              onTap: () => _showStickyNoteDetail(note),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF08A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCA8A04), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sticky_note_2_rounded, size: 14, color: Color(0xFF854D0E)),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        note.noteText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF854D0E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _promptAddStickyNote(double x, double y) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.sticky_note_2_rounded, color: Color(0xFFCA8A04)),
              const SizedBox(width: 8),
              Text(
                'Note Médicale • Page $_currentPage',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: TextField(
            controller: noteController,
            autofocus: true,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Notez une perle, un piège d\'annale, une posologie...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCA8A04),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final text = noteController.text.trim();
                if (text.isNotEmpty) {
                  final note = PdfAnnotationModel(
                    id: 'note_${DateTime.now().millisecondsSinceEpoch}',
                    courseId: _cacheKey,
                    pageNumber: _currentPage,
                    type: PdfAnnotationType.note,
                    colorHex: _selectedColorHex,
                    noteText: text,
                    points: [PdfDrawingPoint(x, y)],
                    createdAt: DateTime.now(),
                  );
                  await _annotationService.addAnnotation(note);
                  if (mounted) setState(() {});
                }
                Navigator.pop(ctx);
              },
              child: const Text('Enregistrer le Post-It'),
            ),
          ],
        );
      },
    );
  }

  void _showStickyNoteDetail(PdfAnnotationModel note) {
    final editController = TextEditingController(text: note.noteText);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.sticky_note_2_rounded, color: Color(0xFFCA8A04)),
              const SizedBox(width: 8),
              Text(
                'Post-It • Page ${note.pageNumber}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Créé le ${note.createdAt.day}/${note.createdAt.month} à ${note.createdAt.hour}h${note.createdAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () async {
                await _annotationService.removeAnnotation(_cacheKey, note.id);
                if (mounted) setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text('Supprimer'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final updated = note.copyWith(noteText: editController.text.trim());
                await _annotationService.removeAnnotation(_cacheKey, note.id);
                await _annotationService.addAnnotation(updated);
                if (mounted) setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  void _showJumpToPageDialog() {
    int target = _currentPage;
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final maxP = _pageCount > 0 ? _pageCount : 1;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.tag_rounded, color: AppTheme.primaryTeal),
                  SizedBox(width: 8),
                  Text('Aller à la page', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Document de $maxP pages'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        onPressed: target > 1
                            ? () {
                                setDialogState(() {
                                  target--;
                                  controller.text = '$target';
                                });
                              }
                            : null,
                      ),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (val) {
                            final p = int.tryParse(val);
                            if (p != null && p >= 1 && p <= maxP) {
                              setDialogState(() => target = p);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        onPressed: target < maxP
                            ? () {
                                setDialogState(() {
                                  target++;
                                  controller.text = '$target';
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                  if (maxP > 1) ...[
                    const SizedBox(height: 10),
                    Slider(
                      value: target.toDouble().clamp(1.0, maxP.toDouble()),
                      min: 1.0,
                      max: maxP.toDouble(),
                      divisions: maxP > 1 ? maxP - 1 : 1,
                      activeColor: AppTheme.primaryTeal,
                      onChanged: (val) {
                        setDialogState(() {
                          target = val.round();
                          controller.text = '$target';
                        });
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (target >= 1 && target <= maxP) {
                      _pdfController.jumpToPage(target);
                    }
                  },
                  child: const Text('Aller'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReadingComfortModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Confort de Lecture & Affichage',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        _buildModeCard(
                          label: 'Jour',
                          icon: Icons.wb_sunny_rounded,
                          color: const Color(0xFF0284C7),
                          isSelected: _readingComfortMode == ReadingComfortMode.day,
                          onTap: () {
                            setState(() {
                              _readingComfortMode = ReadingComfortMode.day;
                              _isDarkMode = false;
                            });
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(width: 10),
                        _buildModeCard(
                          label: 'Sépia Chaud',
                          icon: Icons.auto_stories_rounded,
                          color: const Color(0xFFD97706),
                          isSelected: _readingComfortMode == ReadingComfortMode.sepia,
                          onTap: () {
                            setState(() {
                              _readingComfortMode = ReadingComfortMode.sepia;
                              _isDarkMode = false;
                            });
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(width: 10),
                        _buildModeCard(
                          label: 'Nuit OLED',
                          icon: Icons.nightlight_round,
                          color: const Color(0xFF8B5CF6),
                          isSelected: _readingComfortMode == ReadingComfortMode.night,
                          onTap: () {
                            setState(() {
                              _readingComfortMode = ReadingComfortMode.night;
                              _isDarkMode = true;
                            });
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Mode Page par Page', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      subtitle: Text(
                        _isSinglePageLayout ? 'Une seule page à la fois' : 'Défilement vertical continu (recommandé)',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      value: _isSinglePageLayout,
                      activeColor: AppTheme.primaryTeal,
                      onChanged: (val) {
                        setState(() => _isSinglePageLayout = val);
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModeCard({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseNotesList() {
    final notes = _annotationService.getNotesForCourse(_cacheKey);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.sticky_note_2_rounded, color: AppTheme.primaryTeal),
                  const SizedBox(width: 8),
                  Text(
                    'Notes & Post-Its du Cours (${notes.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              if (notes.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.note_add_rounded, size: 48, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 10),
                        const Text(
                          'Aucun post-it sur ce cours',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Activez l\'outil Post-It 📌 dans la barre d\'outils et touchez la page pour ajouter une note médicale.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final n = notes[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF9C3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCA8A04).withOpacity(0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCA8A04),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'P. ${n.pageNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.noteText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF713F12),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${n.createdAt.day}/${n.createdAt.month}/${n.createdAt.year} à ${n.createdAt.hour}h${n.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? Colors.white54 : const Color(0xFFA16207),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                              tooltip: 'Aller à cette page',
                              onPressed: () {
                                Navigator.pop(ctx);
                                _pdfController.jumpToPage(n.pageNumber);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                              tooltip: 'Supprimer la note',
                              onPressed: () async {
                                await _annotationService.removeAnnotation(_cacheKey, n.id);
                                if (mounted) setState(() {});
                                Navigator.pop(ctx);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showBookmarksSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = _pageCount > 0 ? _pageCount : 1;

    final sections = [
      {'title': '1. Début & Introduction', 'page': 1, 'icon': Icons.play_arrow_rounded},
      {'title': '2. Épidémiologie & Rappels', 'page': (total * 0.15).ceil().clamp(1, total), 'icon': Icons.insights_rounded},
      {'title': '3. Diagnostic Positif & Clinique', 'page': (total * 0.35).ceil().clamp(1, total), 'icon': Icons.medical_services_rounded},
      {'title': '4. Examens Complémentaires & Bilan', 'page': (total * 0.55).ceil().clamp(1, total), 'icon': Icons.biotech_rounded},
      {'title': '5. Traitement & Thérapeutique', 'page': (total * 0.75).ceil().clamp(1, total), 'icon': Icons.medication_rounded},
      {'title': '6. Évolution & Pronostic', 'page': total, 'icon': Icons.flag_rounded},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.bookmarks_rounded, color: AppTheme.primaryTeal),
                    SizedBox(width: 8),
                    Text(
                      'Sommaire & Navigation Rapide',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...sections.map((sec) {
                  final page = sec['page'] as int;
                  final isCurrent = _currentPage == page;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(sec['icon'] as IconData, color: isCurrent ? AppTheme.primaryTeal : Colors.grey),
                    title: Text(
                      sec['title'] as String,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        color: isCurrent ? AppTheme.primaryTeal : null,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrent ? AppTheme.primaryTeal.withOpacity(0.15) : Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'P. $page',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? AppTheme.primaryTeal : null,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pdfController.jumpToPage(page);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<PdfAnnotationModel> savedAnnotations;
  final List<PdfDrawingPoint> activeStroke;
  final Color activeColor;

  _DrawingPainter({
    required this.savedAnnotations,
    required this.activeStroke,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ann in savedAnnotations) {
      if (ann.points.length < 2) continue;
      final color = parseHex(ann.colorHex);
      final isHighlighter = ann.type == PdfAnnotationType.highlight;

      final paint = Paint()
        ..color = isHighlighter ? color.withOpacity(0.35) : color.withOpacity(0.9)
        ..strokeWidth = isHighlighter ? 18.0 : ann.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(ann.points.first.x, ann.points.first.y);
      for (int i = 1; i < ann.points.length; i++) {
        path.lineTo(ann.points[i].x, ann.points[i].y);
      }
      canvas.drawPath(path, paint);
    }

    if (activeStroke.length >= 2) {
      final paint = Paint()
        ..color = activeColor.withOpacity(0.9)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(activeStroke.first.x, activeStroke.first.y);
      for (int i = 1; i < activeStroke.length; i++) {
        path.lineTo(activeStroke[i].x, activeStroke[i].y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;

  static Color parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFFFACC15);
    }
  }
}
