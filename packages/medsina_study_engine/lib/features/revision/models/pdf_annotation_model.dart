import 'dart:ui';

enum PdfAnnotationType {
  highlight,
  underline,
  strikethrough,
  note,
  drawing,
}

class PdfDrawingPoint {
  final double x;
  final double y;

  const PdfDrawingPoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory PdfDrawingPoint.fromJson(Map<String, dynamic> json) {
    return PdfDrawingPoint(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    );
  }
}

class PdfAnnotationModel {
  final String id;
  final String courseId;
  final int pageNumber;
  final PdfAnnotationType type;
  final String colorHex;
  final String noteText;
  final List<PdfDrawingPoint> points;
  final double strokeWidth;
  final DateTime createdAt;

  const PdfAnnotationModel({
    required this.id,
    required this.courseId,
    required this.pageNumber,
    required this.type,
    required this.colorHex,
    this.noteText = '',
    this.points = const [],
    this.strokeWidth = 3.0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'pageNumber': pageNumber,
        'type': type.name,
        'colorHex': colorHex,
        'noteText': noteText,
        'points': points.map((p) => p.toJson()).toList(),
        'strokeWidth': strokeWidth,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PdfAnnotationModel.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    return PdfAnnotationModel(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      pageNumber: json['pageNumber'] as int,
      type: PdfAnnotationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PdfAnnotationType.note,
      ),
      colorHex: json['colorHex'] as String? ?? '#FACC15',
      noteText: json['noteText'] as String? ?? '',
      points: rawPoints
          .map((p) => PdfDrawingPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  PdfAnnotationModel copyWith({
    String? id,
    String? courseId,
    int? pageNumber,
    PdfAnnotationType? type,
    String? colorHex,
    String? noteText,
    List<PdfDrawingPoint>? points,
    double? strokeWidth,
    DateTime? createdAt,
  }) {
    return PdfAnnotationModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      pageNumber: pageNumber ?? this.pageNumber,
      type: type ?? this.type,
      colorHex: colorHex ?? this.colorHex,
      noteText: noteText ?? this.noteText,
      points: points ?? this.points,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
