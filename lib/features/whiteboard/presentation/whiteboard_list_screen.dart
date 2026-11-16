import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/whiteboard_model.dart';
import '../models/whiteboard_templates.dart';
import '../services/whiteboard_repository.dart';
import 'whiteboard_editor_screen.dart';

class WhiteboardListScreen extends StatefulWidget {
  final String? courseId;
  final String? courseTitle;
  final String? moduleName;
  final bool embedded;

  const WhiteboardListScreen({
    super.key,
    this.courseId,
    this.courseTitle,
    this.moduleName,
    this.embedded = false,
  });

  @override
  State<WhiteboardListScreen> createState() => _WhiteboardListScreenState();
}

class _WhiteboardListScreenState extends State<WhiteboardListScreen> {
  List<WhiteboardModel> _boards = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  Future<void> _loadBoards() async {
    setState(() => _isLoading = true);
    final boards = await WhiteboardRepository.fetchBoards(
      courseId: widget.courseId,
    );
    if (mounted) {
      setState(() {
        _boards = boards;
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewBoard() async {
    final titleCtrl = TextEditingController(
      text: widget.courseTitle != null
          ? 'Mindmap • ${widget.courseTitle}'
          : 'Mon Schéma de Révision',
    );
    WhiteboardTemplateType selectedTemplate = WhiteboardTemplateType.mindmap;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nouveau Whiteboard / Mindmap'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Titre du tableau',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choisir un modèle de départ :',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...WhiteboardTemplates.all.map(
                  (tpl) => RadioListTile<WhiteboardTemplateType>(
                    value: tpl.type,
                    groupValue: selectedTemplate,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tpl.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      tpl.description,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedTemplate = val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Créer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final title = titleCtrl.text.trim().isEmpty
        ? 'Nouveau Whiteboard'
        : titleCtrl.text.trim();
    final now = DateTime.now();
    final id =
        'wb_${now.microsecondsSinceEpoch}_${math.Random().nextInt(9999)}';
    final newBoard = WhiteboardModel(
      id: id,
      title: title,
      courseId: widget.courseId,
      moduleName: widget.moduleName,
      data: WhiteboardTemplates.build(
        selectedTemplate,
        topicTitle: widget.courseTitle ?? title,
      ),
      createdAt: now,
      updatedAt: now,
    );

    final saved = await WhiteboardRepository.saveBoard(newBoard);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WhiteboardEditorScreen(board: saved),
      ),
    );
    _loadBoards();
  }

  Future<void> _openBoard(WhiteboardModel board) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WhiteboardEditorScreen(board: board),
      ),
    );
    _loadBoards();
  }

  Future<void> _deleteBoard(WhiteboardModel board) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce Whiteboard ?'),
        content: Text('« ${board.title} » sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await WhiteboardRepository.deleteBoard(board.id);
      _loadBoards();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _boards.where((b) {
      if (_search.trim().isEmpty) return true;
      final q = _search.toLowerCase();
      return b.title.toLowerCase().contains(q) ||
          (b.moduleName?.toLowerCase().contains(q) ?? false);
    }).toList();

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un whiteboard ou mindmap...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _createNewBoard,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Nouveau'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadBoards,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final board = filtered[i];
                          return _WhiteboardCard(
                            board: board,
                            onTap: () => _openBoard(board),
                            onDelete: () => _deleteBoard(board),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.courseTitle != null
              ? 'Mes Mindmaps • ${widget.courseTitle}'
              : 'Whiteboard & Mindmaps',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: content,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.draw_rounded,
              size: 64,
              color: AppTheme.primaryTeal.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 14),
            const Text(
              'Créez votre premier Whiteboard',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Dessinez vos propres cartes mentales, schémas de physiopathologie ou arbres décisionnels et téléchargez-les en PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _createNewBoard,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer un Mindmap'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteboardCard extends StatelessWidget {
  final WhiteboardModel board;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WhiteboardCard({
    required this.board,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy • HH:mm').format(board.updatedAt);
    final nodeCount = board.data.nodes.length;
    final strokeCount = board.data.strokes.length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.account_tree_rounded,
            color: AppTheme.primaryTeal,
          ),
        ),
        title: Text(
          board.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$nodeCount noeuds • $strokeCount tracés • $dateStr',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (board.moduleName != null && board.moduleName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  board.moduleName!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              board.isSynced
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              size: 18,
              color: board.isSynced ? AppTheme.primaryTeal : Colors.grey,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
