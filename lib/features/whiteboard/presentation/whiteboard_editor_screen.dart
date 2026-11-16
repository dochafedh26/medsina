import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/whiteboard_controller.dart';
import '../models/whiteboard_model.dart';
import '../models/whiteboard_templates.dart';
import '../services/whiteboard_pdf_exporter.dart';
import '../services/whiteboard_repository.dart';
import 'widgets/whiteboard_node_widget.dart';
import 'widgets/whiteboard_painter.dart';

class WhiteboardEditorScreen extends StatefulWidget {
  final WhiteboardModel board;

  const WhiteboardEditorScreen({super.key, required this.board});

  @override
  State<WhiteboardEditorScreen> createState() => _WhiteboardEditorScreenState();
}

class _WhiteboardEditorScreenState extends State<WhiteboardEditorScreen> {
  static const double _canvasWidth = 2400;
  static const double _canvasHeight = 1800;

  late WhiteboardModel _board;
  late WhiteboardController _controller;
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  bool _isSaving = false;
  bool _isExportingPdf = false;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _board = widget.board;
    _controller = WhiteboardController(initialData: _board.data)
      ..addListener(_onControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerView();
    });
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
      if (_controller.hasUnsavedChanges) {
        _scheduleAutoSave();
      }
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveBoard(silent: true);
    });
  }

  void _centerView() {
    final size = MediaQuery.of(context).size;
    const double targetX = 1200;
    const double targetY = 1120;
    final double tx = (size.width / 2) - targetX;
    final double ty = (size.height / 2) - targetY;
    _transformController.value = Matrix4.identity()..translate(tx, ty);
  }

  void _zoomBy(double factor) {
    final current = _transformController.value.clone();
    final scale = current.getMaxScaleOnAxis();
    final nextScale = (scale * factor).clamp(0.3, 3.0);
    final appliedFactor = nextScale / scale;
    final size = MediaQuery.of(context).size;
    final focal = Offset(size.width / 2, size.height / 2);

    _transformController.value = Matrix4.identity()
      ..translate(focal.dx, focal.dy)
      ..scale(appliedFactor)
      ..translate(-focal.dx, -focal.dy)
      ..multiply(current);
  }

  Future<void> _saveBoard({bool silent = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final updated = _board.copyWith(
        data: _controller.data,
        updatedAt: DateTime.now(),
      );
      final saved = await WhiteboardRepository.saveBoard(updated);
      _board = saved;
      _controller.markSaved();
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved.isSynced
                  ? 'Whiteboard enregistré et synchronisé'
                  : 'Whiteboard enregistré localement',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_isExportingPdf) return;
    _controller.clearSelection();
    setState(() => _isExportingPdf = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final path = await WhiteboardPdfExporter.exportCanvasToPdf(
        repaintBoundaryKey: _repaintBoundaryKey,
        title: _board.title,
        moduleName: _board.moduleName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              path != null
                  ? 'PDF généré : ${_board.title}.pdf'
                  : 'PDF généré avec succès',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export PDF : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _renameBoard() async {
    final textCtrl = TextEditingController(text: _board.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer le Whiteboard'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Titre',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      setState(() => _board = _board.copyWith(title: newTitle));
      await _saveBoard(silent: true);
    }
  }

  Future<void> _showNodeDialog({
    WhiteboardNode? existing,
    Offset? createAt,
  }) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final subCtrl = TextEditingController(text: existing?.subtitle ?? '');
    WhiteboardNodeShape shape = existing?.shape ?? WhiteboardNodeShape.rounded;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Nouveau Noeud' : 'Modifier le Noeud'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Titre / Concept',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Détails / Notes (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<WhiteboardNodeShape>(
                segments: const [
                  ButtonSegment(
                    value: WhiteboardNodeShape.rounded,
                    label: Text('Carte'),
                  ),
                  ButtonSegment(
                    value: WhiteboardNodeShape.pill,
                    label: Text('Pilule'),
                  ),
                  ButtonSegment(
                    value: WhiteboardNodeShape.diamond,
                    label: Text('Décision'),
                  ),
                ],
                selected: {shape},
                onSelectionChanged: (val) =>
                    setDialogState(() => shape = val.first),
              ),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () {
                  _controller.selectNode(existing.id);
                  _controller.deleteSelected();
                  Navigator.pop(ctx, false);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final title =
          titleCtrl.text.trim().isEmpty ? 'Concept' : titleCtrl.text.trim();
      final subtitle = subCtrl.text.trim();
      if (existing != null) {
        _controller.updateNode(
          existing.id,
          title: title,
          subtitle: subtitle,
          shape: shape,
        );
      } else if (createAt != null) {
        _controller.addNode(
          position: createAt,
          title: title,
          subtitle: subtitle,
          shape: shape,
        );
        _controller.setTool(WhiteboardTool.select);
      }
    }
  }

  Future<void> _showTextDialog(Offset position) async {
    final textCtrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un texte'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ex: Triade de Charcot...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) {
      _controller.addTextShape(position: position, text: text);
      _controller.setTool(WhiteboardTool.select);
    }
  }

  Future<void> _showTemplatePicker() async {
    final selected = await showModalBottomSheet<WhiteboardTemplateType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Appliquer un modèle',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...WhiteboardTemplates.all.map(
                (t) => ListTile(
                  leading: const Icon(Icons.account_tree_rounded),
                  title: Text(t.title),
                  subtitle: Text(t.description),
                  onTap: () => Navigator.pop(ctx, t.type),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      _controller.loadData(
        WhiteboardTemplates.build(selected, topicTitle: _board.title),
      );
      _centerView();
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelectTool = _controller.activeTool == WhiteboardTool.select;
    final hasSelection =
        _controller.selectedNodeId != null ||
        _controller.selectedShapeId != null;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _controller.hasUnsavedChanges) {
          _saveBoard(silent: true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: _renameBoard,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _board.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit_rounded, size: 15),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Annuler',
              onPressed: _controller.canUndo ? _controller.undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: 'Rétablir',
              onPressed: _controller.canRedo ? _controller.redo : null,
              icon: const Icon(Icons.redo_rounded),
            ),
            IconButton(
              tooltip: 'Télécharger en PDF',
              onPressed: _isExportingPdf ? null : _exportPdf,
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
            ),
            IconButton(
              tooltip: 'Enregistrer',
              onPressed: _isSaving ? null : () => _saveBoard(silent: false),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _board.isSynced && !_controller.hasUnsavedChanges
                          ? Icons.cloud_done_rounded
                          : Icons.save_rounded,
                    ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'template':
                    _showTemplatePicker();
                    break;
                  case 'bg_dots':
                    _controller
                        .setBackgroundStyle(WhiteboardBackgroundStyle.dots);
                    break;
                  case 'bg_grid':
                    _controller
                        .setBackgroundStyle(WhiteboardBackgroundStyle.grid);
                    break;
                  case 'bg_plain':
                    _controller
                        .setBackgroundStyle(WhiteboardBackgroundStyle.plain);
                    break;
                  case 'clear':
                    _controller.clearCanvas();
                    break;
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'template',
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome_mosaic_rounded),
                    title: Text('Modèles Mindmap'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'bg_dots',
                  child: Text('Fond : Points'),
                ),
                PopupMenuItem(
                  value: 'bg_grid',
                  child: Text('Fond : Grille'),
                ),
                PopupMenuItem(
                  value: 'bg_plain',
                  child: Text('Fond : Uni'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'clear',
                  child: Text(
                    'Tout effacer',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformController,
              constrained: false,
              minScale: 0.25,
              maxScale: 3.0,
              panEnabled: isSelectTool,
              scaleEnabled: true,
              boundaryMargin: const EdgeInsets.all(600),
              child: RepaintBoundary(
                key: _repaintBoundaryKey,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    if (_controller.activeTool == WhiteboardTool.node) {
                      _showNodeDialog(createAt: details.localPosition);
                    } else if (_controller.activeTool == WhiteboardTool.text) {
                      _showTextDialog(details.localPosition);
                    } else if (_controller.activeTool ==
                        WhiteboardTool.select) {
                      _controller.clearSelection();
                    }
                  },
                  onPanStart: isSelectTool
                      ? null
                      : (details) =>
                          _controller.onCanvasPanStart(details.localPosition),
                  onPanUpdate: isSelectTool
                      ? null
                      : (details) => _controller.onCanvasPanUpdate(
                            details.localPosition,
                            details.delta,
                          ),
                  onPanEnd: isSelectTool
                      ? null
                      : (_) => _controller.onCanvasPanEnd(),
                  child: SizedBox(
                    width: _canvasWidth,
                    height: _canvasHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: WhiteboardPainter(
                              data: _controller.data,
                              activeStroke: _controller.activeStroke,
                              connectorStart: _controller.connectorStart,
                              connectorCurrent: _controller.connectorCurrent,
                              activeShapePreview:
                                  _controller.activeShapePreview,
                              activeTool: _controller.activeTool,
                              activeColorValue: _controller.activeColorValue,
                              selectedShapeId: _controller.selectedShapeId,
                              isDarkMode: isDark,
                            ),
                          ),
                        ),
                        ..._controller.data.nodes.map(
                          (node) => WhiteboardNodeWidget(
                            node: node,
                            isSelected:
                                _controller.selectedNodeId == node.id,
                            canDrag: isSelectTool,
                            onTap: () => _controller.selectNode(node.id),
                            onDoubleTap: () =>
                                _showNodeDialog(existing: node),
                            onDragStart: _controller.beginNodeDrag,
                            onDragUpdate: (delta) =>
                                _controller.moveNode(node.id, delta),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Top-right Zoom Controls
            Positioned(
              top: 12,
              right: 12,
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Zoom +',
                      icon: const Icon(Icons.add_rounded, size: 20),
                      onPressed: () => _zoomBy(1.2),
                    ),
                    IconButton(
                      tooltip: 'Centrer',
                      icon: const Icon(Icons.center_focus_strong_rounded,
                          size: 18),
                      onPressed: _centerView,
                    ),
                    IconButton(
                      tooltip: 'Zoom -',
                      icon: const Icon(Icons.remove_rounded, size: 20),
                      onPressed: () => _zoomBy(0.82),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Floating Toolbar + Color Strip
            Positioned(
              left: 12,
              right: 12,
              bottom: 14,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasSelection)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_controller.selectedNodeId != null)
                              FilledButton.icon(
                                onPressed: () {
                                  final node = _controller.data.nodes.firstWhere(
                                    (n) => n.id == _controller.selectedNodeId,
                                  );
                                  _showNodeDialog(existing: node);
                                },
                                icon: const Icon(Icons.edit_rounded, size: 16),
                                label: const Text('Modifier'),
                              ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                              ),
                              onPressed: _controller.deleteSelected,
                              icon: const Icon(Icons.delete_rounded, size: 16),
                              label: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B).withValues(alpha: 0.96)
                            : Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _ToolButton(
                                  icon: Icons.pan_tool_alt_rounded,
                                  label: 'Déplacer',
                                  tool: WhiteboardTool.select,
                                  activeTool: _controller.activeTool,
                                  onTap: () => _controller
                                      .setTool(WhiteboardTool.select),
                                ),
                                _ToolButton(
                                  icon: Icons.add_box_rounded,
                                  label: 'Noeud',
                                  tool: WhiteboardTool.node,
                                  activeTool: _controller.activeTool,
                                  onTap: () =>
                                      _controller.setTool(WhiteboardTool.node),
                                ),
                                _ToolButton(
                                  icon: Icons.trending_flat_rounded,
                                  label: 'Flèche',
                                  tool: WhiteboardTool.connector,
                                  activeTool: _controller.activeTool,
                                  onTap: () => _controller
                                      .setTool(WhiteboardTool.connector),
                                ),
                                _ToolButton(
                                  icon: Icons.draw_rounded,
                                  label: 'Stylo',
                                  tool: WhiteboardTool.pen,
                                  activeTool: _controller.activeTool,
                                  onTap: () =>
                                      _controller.setTool(WhiteboardTool.pen),
                                ),
                                _ToolButton(
                                  icon: Icons.highlight_rounded,
                                  label: 'Surligner',
                                  tool: WhiteboardTool.highlighter,
                                  activeTool: _controller.activeTool,
                                  onTap: () => _controller
                                      .setTool(WhiteboardTool.highlighter),
                                ),
                                _ToolButton(
                                  icon: Icons.crop_square_rounded,
                                  label: 'Cadre',
                                  tool: WhiteboardTool.rect,
                                  activeTool: _controller.activeTool,
                                  onTap: () =>
                                      _controller.setTool(WhiteboardTool.rect),
                                ),
                                _ToolButton(
                                  icon: Icons.circle_outlined,
                                  label: 'Cercle',
                                  tool: WhiteboardTool.circle,
                                  activeTool: _controller.activeTool,
                                  onTap: () => _controller
                                      .setTool(WhiteboardTool.circle),
                                ),
                                _ToolButton(
                                  icon: Icons.title_rounded,
                                  label: 'Texte',
                                  tool: WhiteboardTool.text,
                                  activeTool: _controller.activeTool,
                                  onTap: () =>
                                      _controller.setTool(WhiteboardTool.text),
                                ),
                                _ToolButton(
                                  icon: Icons.cleaning_services_rounded,
                                  label: 'Gomme',
                                  tool: WhiteboardTool.eraser,
                                  activeTool: _controller.activeTool,
                                  onTap: () => _controller
                                      .setTool(WhiteboardTool.eraser),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: WhiteboardPalette.colors.map((c) {
                                final isSelected =
                                    _controller.activeColorValue == c;
                                return GestureDetector(
                                  onTap: () => _controller.setColor(c),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(c),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? (isDark
                                                ? Colors.white
                                                : Colors.black)
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final WhiteboardTool tool;
  final WhiteboardTool activeTool;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.tool,
    required this.activeTool,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = tool == activeTool;
    final activeColor = AppTheme.primaryTeal;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? activeColor : null,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? activeColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
