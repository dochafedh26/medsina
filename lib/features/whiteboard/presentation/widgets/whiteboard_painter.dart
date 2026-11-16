import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/whiteboard_model.dart';

class WhiteboardPainter extends CustomPainter {
  final WhiteboardCanvasData data;
  final WhiteboardStroke? activeStroke;
  final Offset? connectorStart;
  final Offset? connectorCurrent;
  final Rect? activeShapePreview;
  final WhiteboardTool activeTool;
  final int activeColorValue;
  final String? selectedShapeId;
  final bool isDarkMode;

  WhiteboardPainter({
    required this.data,
    required this.activeStroke,
    required this.connectorStart,
    required this.connectorCurrent,
    required this.activeShapePreview,
    required this.activeTool,
    required this.activeColorValue,
    required this.selectedShapeId,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintShapes(canvas);
    _paintConnectors(canvas);
    _paintStrokes(canvas);
    _paintPreviews(canvas);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF0B1120) : const Color(0xFFFAFAFC);
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (data.backgroundStyle == WhiteboardBackgroundStyle.plain) return;

    const double step = 32.0;
    final dotColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFF94A3B8).withValues(alpha: 0.28);

    if (data.backgroundStyle == WhiteboardBackgroundStyle.dots) {
      final dotPaint = Paint()..color = dotColor;
      for (double x = step; x < size.width; x += step) {
        for (double y = step; y < size.height; y += step) {
          canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
        }
      }
    } else if (data.backgroundStyle == WhiteboardBackgroundStyle.grid) {
      final linePaint = Paint()
        ..color = dotColor.withValues(alpha: isDarkMode ? 0.06 : 0.16)
        ..strokeWidth = 1.0;
      for (double x = 0; x <= size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
      for (double y = 0; y <= size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    }
  }

  void _paintShapes(Canvas canvas) {
    for (final shape in data.shapes) {
      final color = Color(shape.colorValue);
      final isSelected = shape.id == selectedShapeId;
      final rect = shape.rect;

      if (shape.type == WhiteboardShapeType.rect) {
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
        if (shape.filled) {
          canvas.drawRRect(
            rrect,
            Paint()..color = color.withValues(alpha: 0.14),
          );
        }
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4,
        );
      } else if (shape.type == WhiteboardShapeType.circle) {
        if (shape.filled) {
          canvas.drawOval(
            rect,
            Paint()..color = color.withValues(alpha: 0.14),
          );
        }
        canvas.drawOval(
          rect,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4,
        );
      } else if (shape.type == WhiteboardShapeType.text) {
        final tp = TextPainter(
          text: TextSpan(
            text: shape.text,
            style: TextStyle(
              color: isDarkMode ? Colors.white : color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: math.max(120, rect.width));
        tp.paint(canvas, Offset(rect.left + 6, rect.top + 6));
      }

      if (isSelected) {
        canvas.drawRect(
          rect.inflate(5),
          Paint()
            ..color = const Color(0xFF0D9488)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }
  }

  void _paintConnectors(Canvas canvas) {
    final nodeMap = {for (final n in data.nodes) n.id: n};

    for (final conn in data.connectors) {
      final fromNode =
          conn.fromNodeId != null ? nodeMap[conn.fromNodeId] : null;
      final toNode = conn.toNodeId != null ? nodeMap[conn.toNodeId] : null;

      Offset start = fromNode?.center ?? Offset(conn.startX, conn.startY);
      Offset end = toNode?.center ?? Offset(conn.endX, conn.endY);

      if (fromNode != null) {
        start = _borderPoint(fromNode.rect, end);
      }
      if (toNode != null) {
        end = _borderPoint(toNode.rect, start);
      }

      _drawCurvedArrow(
        canvas: canvas,
        start: start,
        end: end,
        color: Color(conn.colorValue),
        label: conn.label,
      );
    }
  }

  Offset _borderPoint(Rect rect, Offset target) {
    final center = rect.center;
    final dx = target.dx - center.dx;
    final dy = target.dy - center.dy;
    if (dx == 0 && dy == 0) return center;

    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final scaleX = dx != 0 ? (halfW / dx.abs()) : double.infinity;
    final scaleY = dy != 0 ? (halfH / dy.abs()) : double.infinity;
    final scale = math.min(scaleX, scaleY);

    return Offset(center.dx + dx * scale, center.dy + dy * scale);
  }

  void _drawCurvedArrow({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required Color color,
    String label = '',
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final dx = (end.dx - start.dx) * 0.45;
    final cp1 = Offset(start.dx + dx, start.dy);
    final cp2 = Offset(end.dx - dx, end.dy);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);

    canvas.drawPath(path, paint);

    // Arrowhead angle from cp2 -> end
    final angle = math.atan2(end.dy - cp2.dy, end.dx - cp2.dx);
    const arrowLen = 11.0;
    const arrowAngle = 0.48;

    final p1 = Offset(
      end.dx - arrowLen * math.cos(angle - arrowAngle),
      end.dy - arrowLen * math.sin(angle - arrowAngle),
    );
    final p2 = Offset(
      end.dx - arrowLen * math.cos(angle + arrowAngle),
      end.dy - arrowLen * math.sin(angle + arrowAngle),
    );

    final headPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    canvas.drawPath(headPath, Paint()..color = color);

    if (label.isNotEmpty) {
      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pillRect = Rect.fromCenter(
        center: mid,
        width: tp.width + 12,
        height: tp.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pillRect, const Radius.circular(8)),
        Paint()
          ..color = isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      );
      tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
    }
  }

  void _paintStrokes(Canvas canvas) {
    for (final stroke in data.strokes) {
      _drawSmoothStroke(canvas, stroke);
    }
  }

  void _drawSmoothStroke(Canvas canvas, WhiteboardStroke stroke) {
    if (stroke.points.isEmpty) return;
    final color = Color(stroke.colorValue).withValues(
      alpha: stroke.isHighlighter ? 0.34 : 1.0,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first,
        stroke.strokeWidth / 2,
        Paint()..color = color,
      );
      return;
    }

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length - 1; i++) {
      final p0 = stroke.points[i];
      final p1 = stroke.points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    canvas.drawPath(path, paint);
  }

  void _paintPreviews(Canvas canvas) {
    if (activeStroke != null) {
      _drawSmoothStroke(canvas, activeStroke!);
    }
    if (connectorStart != null && connectorCurrent != null) {
      _drawCurvedArrow(
        canvas: canvas,
        start: connectorStart!,
        end: connectorCurrent!,
        color: Color(activeColorValue).withValues(alpha: 0.75),
      );
    }
    if (activeShapePreview != null) {
      final paint = Paint()
        ..color = Color(activeColorValue).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      if (activeTool == WhiteboardTool.circle) {
        canvas.drawOval(activeShapePreview!, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            activeShapePreview!,
            const Radius.circular(12),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant WhiteboardPainter oldDelegate) => true;
}
