import 'package:flutter/material.dart';

enum WhiteboardTool {
  select,
  node,
  connector,
  pen,
  highlighter,
  rect,
  circle,
  text,
  eraser,
}

enum WhiteboardNodeShape {
  rounded,
  pill,
  diamond,
}

enum WhiteboardBackgroundStyle {
  dots,
  grid,
  plain,
}

enum WhiteboardShapeType {
  rect,
  circle,
  text,
}

class WhiteboardPalette {
  static const List<int> colors = [
    0xFF0D9488, // Medsina Teal
    0xFF0F172A, // Clinical Navy
    0xFF2563EB, // Royal Blue
    0xFF7C3AED, // Violet
    0xFFDC2626, // Crimson
    0xFFD97706, // Amber
    0xFF059669, // Emerald
    0xFFDB2777, // Pink
  ];
}

class WhiteboardNode {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String title;
  final String subtitle;
  final int colorValue;
  final WhiteboardNodeShape shape;

  const WhiteboardNode({
    required this.id,
    required this.x,
    required this.y,
    this.width = 180,
    this.height = 76,
    required this.title,
    this.subtitle = '',
    this.colorValue = 0xFF0D9488,
    this.shape = WhiteboardNodeShape.rounded,
  });

  Offset get center => Offset(x + width / 2, y + height / 2);

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  WhiteboardNode copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    double? height,
    String? title,
    String? subtitle,
    int? colorValue,
    WhiteboardNodeShape? shape,
  }) {
    return WhiteboardNode(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      colorValue: colorValue ?? this.colorValue,
      shape: shape ?? this.shape,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'title': title,
        'subtitle': subtitle,
        'colorValue': colorValue,
        'shape': shape.name,
      };

  factory WhiteboardNode.fromJson(Map<String, dynamic> json) {
    return WhiteboardNode(
      id: json['id']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 180,
      height: (json['height'] as num?)?.toDouble() ?? 76,
      title: json['title']?.toString() ?? 'Noeud',
      subtitle: json['subtitle']?.toString() ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF0D9488,
      shape: WhiteboardNodeShape.values.firstWhere(
        (e) => e.name == json['shape'],
        orElse: () => WhiteboardNodeShape.rounded,
      ),
    );
  }
}

class WhiteboardConnector {
  final String id;
  final String? fromNodeId;
  final String? toNodeId;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final String label;
  final int colorValue;
  final bool isDashed;

  const WhiteboardConnector({
    required this.id,
    this.fromNodeId,
    this.toNodeId,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    this.label = '',
    this.colorValue = 0xFF0F172A,
    this.isDashed = false,
  });

  WhiteboardConnector copyWith({
    String? id,
    String? fromNodeId,
    String? toNodeId,
    double? startX,
    double? startY,
    double? endX,
    double? endY,
    String? label,
    int? colorValue,
    bool? isDashed,
  }) {
    return WhiteboardConnector(
      id: id ?? this.id,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      startX: startX ?? this.startX,
      startY: startY ?? this.startY,
      endX: endX ?? this.endX,
      endY: endY ?? this.endY,
      label: label ?? this.label,
      colorValue: colorValue ?? this.colorValue,
      isDashed: isDashed ?? this.isDashed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromNodeId': fromNodeId,
        'toNodeId': toNodeId,
        'startX': startX,
        'startY': startY,
        'endX': endX,
        'endY': endY,
        'label': label,
        'colorValue': colorValue,
        'isDashed': isDashed,
      };

  factory WhiteboardConnector.fromJson(Map<String, dynamic> json) {
    return WhiteboardConnector(
      id: json['id']?.toString() ?? '',
      fromNodeId: json['fromNodeId']?.toString(),
      toNodeId: json['toNodeId']?.toString(),
      startX: (json['startX'] as num?)?.toDouble() ?? 0,
      startY: (json['startY'] as num?)?.toDouble() ?? 0,
      endX: (json['endX'] as num?)?.toDouble() ?? 0,
      endY: (json['endY'] as num?)?.toDouble() ?? 0,
      label: json['label']?.toString() ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF0F172A,
      isDashed: json['isDashed'] == true,
    );
  }
}

class WhiteboardStroke {
  final String id;
  final List<Offset> points;
  final int colorValue;
  final double strokeWidth;
  final bool isHighlighter;

  const WhiteboardStroke({
    required this.id,
    required this.points,
    this.colorValue = 0xFF0F172A,
    this.strokeWidth = 3.0,
    this.isHighlighter = false,
  });

  WhiteboardStroke copyWith({
    String? id,
    List<Offset>? points,
    int? colorValue,
    double? strokeWidth,
    bool? isHighlighter,
  }) {
    return WhiteboardStroke(
      id: id ?? this.id,
      points: points ?? this.points,
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isHighlighter: isHighlighter ?? this.isHighlighter,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'colorValue': colorValue,
        'strokeWidth': strokeWidth,
        'isHighlighter': isHighlighter,
      };

  factory WhiteboardStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List?) ?? const [];
    return WhiteboardStroke(
      id: json['id']?.toString() ?? '',
      points: rawPoints
          .whereType<Map>()
          .map((p) => Offset(
                (p['x'] as num?)?.toDouble() ?? 0,
                (p['y'] as num?)?.toDouble() ?? 0,
              ))
          .toList(),
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF0F172A,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      isHighlighter: json['isHighlighter'] == true,
    );
  }
}

class WhiteboardShape {
  final String id;
  final WhiteboardShapeType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final String text;
  final int colorValue;
  final bool filled;

  const WhiteboardShape({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.text = '',
    this.colorValue = 0xFF2563EB,
    this.filled = false,
  });

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  WhiteboardShape copyWith({
    String? id,
    WhiteboardShapeType? type,
    double? x,
    double? y,
    double? width,
    double? height,
    String? text,
    int? colorValue,
    bool? filled,
  }) {
    return WhiteboardShape(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      text: text ?? this.text,
      colorValue: colorValue ?? this.colorValue,
      filled: filled ?? this.filled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'text': text,
        'colorValue': colorValue,
        'filled': filled,
      };

  factory WhiteboardShape.fromJson(Map<String, dynamic> json) {
    return WhiteboardShape(
      id: json['id']?.toString() ?? '',
      type: WhiteboardShapeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => WhiteboardShapeType.rect,
      ),
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 120,
      height: (json['height'] as num?)?.toDouble() ?? 80,
      text: json['text']?.toString() ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF2563EB,
      filled: json['filled'] == true,
    );
  }
}

class WhiteboardCanvasData {
  final List<WhiteboardNode> nodes;
  final List<WhiteboardConnector> connectors;
  final List<WhiteboardStroke> strokes;
  final List<WhiteboardShape> shapes;
  final WhiteboardBackgroundStyle backgroundStyle;

  const WhiteboardCanvasData({
    this.nodes = const [],
    this.connectors = const [],
    this.strokes = const [],
    this.shapes = const [],
    this.backgroundStyle = WhiteboardBackgroundStyle.dots,
  });

  bool get isEmpty =>
      nodes.isEmpty && connectors.isEmpty && strokes.isEmpty && shapes.isEmpty;

  WhiteboardCanvasData copyWith({
    List<WhiteboardNode>? nodes,
    List<WhiteboardConnector>? connectors,
    List<WhiteboardStroke>? strokes,
    List<WhiteboardShape>? shapes,
    WhiteboardBackgroundStyle? backgroundStyle,
  }) {
    return WhiteboardCanvasData(
      nodes: nodes ?? this.nodes,
      connectors: connectors ?? this.connectors,
      strokes: strokes ?? this.strokes,
      shapes: shapes ?? this.shapes,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
    );
  }

  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((e) => e.toJson()).toList(),
        'connectors': connectors.map((e) => e.toJson()).toList(),
        'strokes': strokes.map((e) => e.toJson()).toList(),
        'shapes': shapes.map((e) => e.toJson()).toList(),
        'backgroundStyle': backgroundStyle.name,
      };

  factory WhiteboardCanvasData.fromJson(Map<String, dynamic> json) {
    return WhiteboardCanvasData(
      nodes: ((json['nodes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => WhiteboardNode.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      connectors: ((json['connectors'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => WhiteboardConnector.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      strokes: ((json['strokes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => WhiteboardStroke.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      shapes: ((json['shapes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => WhiteboardShape.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      backgroundStyle: WhiteboardBackgroundStyle.values.firstWhere(
        (e) => e.name == json['backgroundStyle'],
        orElse: () => WhiteboardBackgroundStyle.dots,
      ),
    );
  }
}

class WhiteboardModel {
  final String id;
  final String title;
  final String? courseId;
  final String? moduleName;
  final WhiteboardCanvasData data;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const WhiteboardModel({
    required this.id,
    required this.title,
    this.courseId,
    this.moduleName,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  WhiteboardModel copyWith({
    String? id,
    String? title,
    String? courseId,
    String? moduleName,
    WhiteboardCanvasData? data,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return WhiteboardModel(
      id: id ?? this.id,
      title: title ?? this.title,
      courseId: courseId ?? this.courseId,
      moduleName: moduleName ?? this.moduleName,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'courseId': courseId,
        'moduleName': moduleName,
        'data': data.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
      };

  factory WhiteboardModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] ?? json['board_data'];
    return WhiteboardModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Nouveau Whiteboard',
      courseId: (json['courseId'] ?? json['course_id'])?.toString(),
      moduleName: (json['moduleName'] ?? json['module_name'])?.toString(),
      data: rawData is Map
          ? WhiteboardCanvasData.fromJson(Map<String, dynamic>.from(rawData))
          : const WhiteboardCanvasData(),
      createdAt: DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            (json['updatedAt'] ?? json['updated_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
      isSynced: json['isSynced'] == true,
    );
  }
}
