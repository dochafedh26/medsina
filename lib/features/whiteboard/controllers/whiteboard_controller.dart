import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/whiteboard_model.dart';

class WhiteboardController extends ChangeNotifier {
  WhiteboardCanvasData _data;
  final List<WhiteboardCanvasData> _undoStack = [];
  final List<WhiteboardCanvasData> _redoStack = [];
  static const int _maxHistory = 60;

  WhiteboardTool _activeTool = WhiteboardTool.select;
  int _activeColorValue = WhiteboardPalette.colors[0];
  double _strokeWidth = 3.5;

  String? _selectedNodeId;
  String? _selectedShapeId;

  // In-progress drawing states (not committed to history until pointer up)
  WhiteboardStroke? _activeStroke;
  Offset? _connectorStart;
  Offset? _connectorCurrent;
  String? _connectorFromNodeId;
  Rect? _activeShapePreview;
  Offset? _shapeDragOrigin;

  bool _hasUnsavedChanges = false;

  WhiteboardController({WhiteboardCanvasData? initialData})
      : _data = initialData ?? const WhiteboardCanvasData();

  WhiteboardCanvasData get data => _data;
  WhiteboardTool get activeTool => _activeTool;
  int get activeColorValue => _activeColorValue;
  double get strokeWidth => _strokeWidth;
  String? get selectedNodeId => _selectedNodeId;
  String? get selectedShapeId => _selectedShapeId;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  WhiteboardStroke? get activeStroke => _activeStroke;
  Offset? get connectorStart => _connectorStart;
  Offset? get connectorCurrent => _connectorCurrent;
  Rect? get activeShapePreview => _activeShapePreview;

  String _nextId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(9999)}';

  void _pushHistory() {
    _undoStack.add(_data);
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _hasUnsavedChanges = true;
  }

  void markSaved() {
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  void setTool(WhiteboardTool tool) {
    _activeTool = tool;
    if (tool != WhiteboardTool.select) {
      _selectedNodeId = null;
      _selectedShapeId = null;
    }
    notifyListeners();
  }

  void setColor(int colorValue) {
    _activeColorValue = colorValue;
    if (_selectedNodeId != null) {
      updateNode(_selectedNodeId!, colorValue: colorValue);
    } else if (_selectedShapeId != null) {
      updateShape(_selectedShapeId!, colorValue: colorValue);
    } else {
      notifyListeners();
    }
  }

  void setStrokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }

  void setBackgroundStyle(WhiteboardBackgroundStyle style) {
    _pushHistory();
    _data = _data.copyWith(backgroundStyle: style);
    notifyListeners();
  }

  void loadData(WhiteboardCanvasData newData, {bool recordHistory = true}) {
    if (recordHistory) _pushHistory();
    _data = newData;
    _selectedNodeId = null;
    _selectedShapeId = null;
    notifyListeners();
  }

  void clearCanvas() {
    if (_data.isEmpty) return;
    _pushHistory();
    _data = WhiteboardCanvasData(backgroundStyle: _data.backgroundStyle);
    _selectedNodeId = null;
    _selectedShapeId = null;
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_data);
    _data = _undoStack.removeLast();
    _selectedNodeId = null;
    _selectedShapeId = null;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_data);
    _data = _redoStack.removeLast();
    _selectedNodeId = null;
    _selectedShapeId = null;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void selectNode(String? nodeId) {
    _selectedNodeId = nodeId;
    _selectedShapeId = null;
    notifyListeners();
  }

  void selectShape(String? shapeId) {
    _selectedShapeId = shapeId;
    _selectedNodeId = null;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedNodeId != null || _selectedShapeId != null) {
      _selectedNodeId = null;
      _selectedShapeId = null;
      notifyListeners();
    }
  }

  WhiteboardNode addNode({
    required Offset position,
    String title = 'Nouvelle idée',
    String subtitle = '',
    WhiteboardNodeShape shape = WhiteboardNodeShape.rounded,
  }) {
    _pushHistory();
    final node = WhiteboardNode(
      id: _nextId('node'),
      x: position.dx - 90,
      y: position.dy - 38,
      title: title,
      subtitle: subtitle,
      colorValue: _activeColorValue,
      shape: shape,
    );
    _data = _data.copyWith(nodes: [..._data.nodes, node]);
    _selectedNodeId = node.id;
    _selectedShapeId = null;
    notifyListeners();
    return node;
  }

  void beginNodeDrag() {
    _pushHistory();
  }

  void moveNode(String nodeId, Offset delta) {
    final nodes = _data.nodes.map((n) {
      if (n.id == nodeId) {
        return n.copyWith(x: n.x + delta.dx, y: n.y + delta.dy);
      }
      return n;
    }).toList();
    _data = _data.copyWith(nodes: nodes);
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  void updateNode(
    String nodeId, {
    String? title,
    String? subtitle,
    int? colorValue,
    WhiteboardNodeShape? shape,
  }) {
    _pushHistory();
    final nodes = _data.nodes.map((n) {
      if (n.id == nodeId) {
        return n.copyWith(
          title: title,
          subtitle: subtitle,
          colorValue: colorValue,
          shape: shape,
        );
      }
      return n;
    }).toList();
    _data = _data.copyWith(nodes: nodes);
    notifyListeners();
  }

  void deleteSelected() {
    if (_selectedNodeId != null) {
      _pushHistory();
      final id = _selectedNodeId!;
      _data = _data.copyWith(
        nodes: _data.nodes.where((n) => n.id != id).toList(),
        connectors: _data.connectors
            .where((c) => c.fromNodeId != id && c.toNodeId != id)
            .toList(),
      );
      _selectedNodeId = null;
      notifyListeners();
    } else if (_selectedShapeId != null) {
      _pushHistory();
      final id = _selectedShapeId!;
      _data = _data.copyWith(
        shapes: _data.shapes.where((s) => s.id != id).toList(),
      );
      _selectedShapeId = null;
      notifyListeners();
    }
  }

  void updateShape(
    String shapeId, {
    String? text,
    int? colorValue,
    bool? filled,
  }) {
    _pushHistory();
    final shapes = _data.shapes.map((s) {
      if (s.id == shapeId) {
        return s.copyWith(
          text: text,
          colorValue: colorValue,
          filled: filled,
        );
      }
      return s;
    }).toList();
    _data = _data.copyWith(shapes: shapes);
    notifyListeners();
  }

  WhiteboardShape addTextShape({
    required Offset position,
    required String text,
  }) {
    _pushHistory();
    final shape = WhiteboardShape(
      id: _nextId('text'),
      type: WhiteboardShapeType.text,
      x: position.dx,
      y: position.dy,
      width: 200,
      height: 48,
      text: text,
      colorValue: _activeColorValue,
    );
    _data = _data.copyWith(shapes: [..._data.shapes, shape]);
    _selectedShapeId = shape.id;
    notifyListeners();
    return shape;
  }

  WhiteboardNode? _findNodeAt(Offset point) {
    for (final node in _data.nodes.reversed) {
      if (node.rect.inflate(10).contains(point)) {
        return node;
      }
    }
    return null;
  }

  WhiteboardShape? _findShapeAt(Offset point) {
    for (final shape in _data.shapes.reversed) {
      if (shape.rect.inflate(8).contains(point)) {
        return shape;
      }
    }
    return null;
  }

  // --- Pointer handling for Canvas ---

  void onCanvasPanStart(Offset localPosition) {
    switch (_activeTool) {
      case WhiteboardTool.pen:
      case WhiteboardTool.highlighter:
        _activeStroke = WhiteboardStroke(
          id: _nextId('stroke'),
          points: [localPosition],
          colorValue: _activeColorValue,
          strokeWidth: _activeTool == WhiteboardTool.highlighter
              ? math.max(14.0, _strokeWidth * 3.5)
              : _strokeWidth,
          isHighlighter: _activeTool == WhiteboardTool.highlighter,
        );
        notifyListeners();
        break;

      case WhiteboardTool.connector:
        final fromNode = _findNodeAt(localPosition);
        _connectorFromNodeId = fromNode?.id;
        _connectorStart = fromNode?.center ?? localPosition;
        _connectorCurrent = localPosition;
        notifyListeners();
        break;

      case WhiteboardTool.rect:
      case WhiteboardTool.circle:
        _shapeDragOrigin = localPosition;
        _activeShapePreview = Rect.fromPoints(localPosition, localPosition);
        notifyListeners();
        break;

      case WhiteboardTool.eraser:
        _eraseNear(localPosition);
        break;

      case WhiteboardTool.select:
        final hitShape = _findShapeAt(localPosition);
        if (hitShape != null) {
          _selectedShapeId = hitShape.id;
          _selectedNodeId = null;
          _pushHistory();
        } else {
          clearSelection();
        }
        notifyListeners();
        break;

      case WhiteboardTool.node:
      case WhiteboardTool.text:
        break;
    }
  }

  void onCanvasPanUpdate(Offset localPosition, Offset delta) {
    switch (_activeTool) {
      case WhiteboardTool.pen:
      case WhiteboardTool.highlighter:
        if (_activeStroke != null) {
          final pts = _activeStroke!.points;
          if (pts.isEmpty || (pts.last - localPosition).distance >= 2.0) {
            _activeStroke = _activeStroke!.copyWith(
              points: [...pts, localPosition],
            );
            notifyListeners();
          }
        }
        break;

      case WhiteboardTool.connector:
        _connectorCurrent = localPosition;
        notifyListeners();
        break;

      case WhiteboardTool.rect:
      case WhiteboardTool.circle:
        if (_shapeDragOrigin != null) {
          _activeShapePreview = Rect.fromPoints(_shapeDragOrigin!, localPosition);
          notifyListeners();
        }
        break;

      case WhiteboardTool.eraser:
        _eraseNear(localPosition);
        break;

      case WhiteboardTool.select:
        if (_selectedShapeId != null) {
          final shapes = _data.shapes.map((s) {
            if (s.id == _selectedShapeId) {
              return s.copyWith(x: s.x + delta.dx, y: s.y + delta.dy);
            }
            return s;
          }).toList();
          _data = _data.copyWith(shapes: shapes);
          _hasUnsavedChanges = true;
          notifyListeners();
        }
        break;

      case WhiteboardTool.node:
      case WhiteboardTool.text:
        break;
    }
  }

  void onCanvasPanEnd() {
    switch (_activeTool) {
      case WhiteboardTool.pen:
      case WhiteboardTool.highlighter:
        if (_activeStroke != null && _activeStroke!.points.isNotEmpty) {
          _pushHistory();
          _data = _data.copyWith(strokes: [..._data.strokes, _activeStroke!]);
        }
        _activeStroke = null;
        notifyListeners();
        break;

      case WhiteboardTool.connector:
        if (_connectorStart != null && _connectorCurrent != null) {
          final toNode = _findNodeAt(_connectorCurrent!);
          final distance = (_connectorCurrent! - _connectorStart!).distance;
          if (distance > 16 ||
              (_connectorFromNodeId != null &&
                  toNode != null &&
                  toNode.id != _connectorFromNodeId)) {
            _pushHistory();
            final connector = WhiteboardConnector(
              id: _nextId('conn'),
              fromNodeId: _connectorFromNodeId,
              toNodeId: toNode?.id,
              startX: _connectorStart!.dx,
              startY: _connectorStart!.dy,
              endX: (toNode?.center ?? _connectorCurrent!).dx,
              endY: (toNode?.center ?? _connectorCurrent!).dy,
              colorValue: _activeColorValue,
            );
            _data = _data.copyWith(
              connectors: [..._data.connectors, connector],
            );
          }
        }
        _connectorStart = null;
        _connectorCurrent = null;
        _connectorFromNodeId = null;
        notifyListeners();
        break;

      case WhiteboardTool.rect:
      case WhiteboardTool.circle:
        if (_activeShapePreview != null &&
            _activeShapePreview!.width > 12 &&
            _activeShapePreview!.height > 12) {
          _pushHistory();
          final shape = WhiteboardShape(
            id: _nextId('shape'),
            type: _activeTool == WhiteboardTool.rect
                ? WhiteboardShapeType.rect
                : WhiteboardShapeType.circle,
            x: _activeShapePreview!.left,
            y: _activeShapePreview!.top,
            width: _activeShapePreview!.width,
            height: _activeShapePreview!.height,
            colorValue: _activeColorValue,
          );
          _data = _data.copyWith(shapes: [..._data.shapes, shape]);
        }
        _activeShapePreview = null;
        _shapeDragOrigin = null;
        notifyListeners();
        break;

      default:
        break;
    }
  }

  void _eraseNear(Offset point) {
    const double radius = 22.0;
    bool changed = false;

    final remainingStrokes = _data.strokes.where((s) {
      final hit = s.points.any((p) => (p - point).distance <= radius);
      if (hit) changed = true;
      return !hit;
    }).toList();

    final remainingShapes = _data.shapes.where((s) {
      final hit = s.rect.inflate(10).contains(point);
      if (hit) changed = true;
      return !hit;
    }).toList();

    final remainingConnectors = _data.connectors.where((c) {
      final start = Offset(c.startX, c.startY);
      final end = Offset(c.endX, c.endY);
      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final hit = (mid - point).distance <= radius * 1.4 ||
          (start - point).distance <= radius ||
          (end - point).distance <= radius;
      if (hit) changed = true;
      return !hit;
    }).toList();

    if (changed) {
      _pushHistory();
      _data = _data.copyWith(
        strokes: remainingStrokes,
        shapes: remainingShapes,
        connectors: remainingConnectors,
      );
      notifyListeners();
    }
  }
}
