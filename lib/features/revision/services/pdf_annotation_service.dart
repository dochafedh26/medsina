import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/cloud_sync_service.dart';
import '../models/pdf_annotation_model.dart';

class PdfAnnotationService extends ChangeNotifier {
  static final PdfAnnotationService instance = PdfAnnotationService._();
  PdfAnnotationService._();

  static const String _prefPrefix = 'medsina_pdf_annotations_';
  final Map<String, List<PdfAnnotationModel>> _cache = {};
  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
  }

  Future<List<PdfAnnotationModel>> getAnnotations(String courseId) async {
    if (_cache.containsKey(courseId)) {
      return _cache[courseId]!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefPrefix$courseId');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        final loaded = list
            .map((e) => PdfAnnotationModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _cache[courseId] = loaded;
        return loaded;
      }
    } catch (e) {
      debugPrint('Error loading PDF annotations for $courseId: $e');
    }

    _cache[courseId] = [];
    return [];
  }

  List<PdfAnnotationModel> getAnnotationsSync(String courseId) {
    return _cache[courseId] ?? [];
  }

  List<PdfAnnotationModel> getAnnotationsForPage(String courseId, int pageNumber) {
    final list = _cache[courseId] ?? [];
    return list.where((a) => a.pageNumber == pageNumber).toList();
  }

  List<PdfAnnotationModel> getNotesForCourse(String courseId) {
    final list = _cache[courseId] ?? [];
    return list
        .where((a) => a.type == PdfAnnotationType.note && a.noteText.trim().isNotEmpty)
        .toList();
  }

  Future<void> addAnnotation(PdfAnnotationModel annotation) async {
    final courseId = annotation.courseId;
    if (!_cache.containsKey(courseId)) {
      await getAnnotations(courseId);
    }

    _cache[courseId]!.add(annotation);
    await _persist(courseId);
    notifyListeners();
  }

  Future<void> removeAnnotation(String courseId, String annotationId) async {
    if (!_cache.containsKey(courseId)) {
      await getAnnotations(courseId);
    }

    _cache[courseId]!.removeWhere((a) => a.id == annotationId);
    await _persist(courseId);
    notifyListeners();
  }

  Future<void> clearPageAnnotations(String courseId, int pageNumber) async {
    if (!_cache.containsKey(courseId)) {
      await getAnnotations(courseId);
    }

    _cache[courseId]!.removeWhere((a) => a.pageNumber == pageNumber);
    await _persist(courseId);
    notifyListeners();
  }

  Future<void> clearAllAnnotations(String courseId) async {
    _cache[courseId] = [];
    await _persist(courseId);
    notifyListeners();
  }

  Future<void> _persist(String courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _cache[courseId] ?? [];
      final encoded = jsonEncode(list.map((a) => a.toJson()).toList());
      await prefs.setString('$_prefPrefix$courseId', encoded);

      CloudSyncService.instance.notifyLocalChange(
        'pdf_annotations',
        list.map((a) => a.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error persisting PDF annotations for $courseId: $e');
    }
  }
}
