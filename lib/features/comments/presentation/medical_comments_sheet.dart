import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/medical_comment.dart';
import '../services/medical_comment_service.dart';

class MedicalCommentsSheet extends StatefulWidget {
  final String targetType; // 'course' or 'qcm'
  final String targetId;
  final String targetTitle;

  const MedicalCommentsSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required String targetTitle,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicalCommentsSheet(
        targetType: targetType,
        targetId: targetId,
        targetTitle: targetTitle,
      ),
    );
  }

  @override
  State<MedicalCommentsSheet> createState() => _MedicalCommentsSheetState();
}

class _MedicalCommentsSheetState extends State<MedicalCommentsSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _filter = 'all'; // 'all', 'public', 'private'
  bool _isPrivateComment = false; // default to public or toggleable
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    await MedicalCommentService.instance.fetchComments(
      widget.targetType,
      widget.targetId,
    );
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await MedicalCommentService.instance.addComment(
        targetType: widget.targetType,
        targetId: widget.targetId,
        targetTitle: widget.targetTitle,
        content: text,
        isPrivate: _isPrivateComment,
      );
      _textController.clear();
      _focusNode.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ajout : $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleDelete(MedicalComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le commentaire ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await MedicalCommentService.instance.deleteComment(
        commentId: comment.id,
        targetType: widget.targetType,
        targetId: widget.targetId,
        isPrivate: comment.isPrivate,
      );
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? 'À l\'instant' : 'Il y a ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays}j';
    }
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} à $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final notifier = MedicalCommentService.instance.getCommentsNotifier(widget.targetId);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: AppTheme.primaryTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.targetType == 'course' ? 'Commentaires du Cours' : 'Commentaires du QCM',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.targetType.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        widget.targetTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ValueListenableBuilder for real-time list
          Expanded(
            child: ValueListenableBuilder<List<MedicalComment>>(
              valueListenable: notifier,
              builder: (context, comments, _) {
                final publicComments = comments.where((c) => !c.isPrivate).toList();
                final privateComments = comments.where((c) => c.isPrivate).toList();

                List<MedicalComment> filteredComments = comments;
                if (_filter == 'public') {
                  filteredComments = publicComments;
                } else if (_filter == 'private') {
                  filteredComments = privateComments;
                }

                return Column(
                  children: [
                    // Filter Chips Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF8FAFC),
                      child: Row(
                        children: [
                          _buildFilterButton('all', 'Tout (${comments.length})', isDark),
                          const SizedBox(width: 8),
                          _buildFilterButton('public', '🌍 Publics (${publicComments.length})', isDark),
                          const SizedBox(width: 8),
                          _buildFilterButton('private', '🔒 Mes Notes (${privateComments.length})', isDark),
                        ],
                      ),
                    ),

                    // Comments List or Empty State
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : filteredComments.isEmpty
                              ? _buildEmptyState(_filter)
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  itemCount: filteredComments.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = filteredComments[index];
                                    return _buildCommentCard(item, isDark);
                                  },
                                ),
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Bottom Add Comment Section
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String key, String label, bool isDark) {
    final isSelected = _filter == key;
    return InkWell(
      onTap: () => setState(() => _filter = key),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryTeal
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryTeal : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    String title = 'Aucun commentaire';
    String message = 'Posez une question, partagez une perle ou enregistrez une note personnelle.';
    IconData icon = Icons.chat_bubble_outline_rounded;

    if (filter == 'private') {
      title = 'Aucune note privée';
      message = 'Ajoutez vos remarques personnelles, mnémotechniques et rappels visibles uniquement par vous.';
      icon = Icons.lock_outline_rounded;
    } else if (filter == 'public') {
      title = 'Aucun commentaire public';
      message = 'Soyez le premier à partager une astuce, un piège de concours ou une explication avec la promo !';
      icon = Icons.public_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCard(MedicalComment item, bool isDark) {
    final isPrivate = item.isPrivate;
    final badgeColor = isPrivate ? const Color(0xFFF59E0B) : AppTheme.primaryTeal;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? (isPrivate ? const Color(0xFF272115) : const Color(0xFF0F172A))
            : (isPrivate ? const Color(0xFFFFFBEB) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrivate
              ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment Author & Privacy Header
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: badgeColor.withValues(alpha: 0.2),
                child: Text(
                  item.userName.isNotEmpty ? item.userName[0].toUpperCase() : 'M',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      _formatTime(item.createdAt),
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              // Badge Private / Public
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                      size: 11,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPrivate ? 'Privé (Moi)' : 'Public',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Delete Option
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                color: Colors.grey.shade500,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Supprimer',
                onPressed: () => _handleDelete(item),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Comment Content
          SelectableText(
            item.content,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isDark ? Colors.grey.shade200 : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Privacy Selector Switch / Pills
          Row(
            children: [
              const Text(
                'Visibilité :',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => setState(() => _isPrivateComment = false),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: !_isPrivateComment
                        ? AppTheme.primaryTeal.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_isPrivateComment ? AppTheme.primaryTeal : Colors.grey.shade400,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.public_rounded,
                        size: 13,
                        color: !_isPrivateComment ? AppTheme.primaryTeal : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Public (Tous)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: !_isPrivateComment ? AppTheme.primaryTeal : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _isPrivateComment = true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isPrivateComment
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isPrivateComment ? const Color(0xFFF59E0B) : Colors.grey.shade400,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: _isPrivateComment ? const Color(0xFFF59E0B) : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Privé (Moi seul)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isPrivateComment ? const Color(0xFFF59E0B) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Input Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: _isPrivateComment
                        ? 'Ajouter une note personnelle (mémo, piège, rappel)...'
                        : 'Partager une question ou explication avec la promo...',
                    hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _isPrivateComment ? const Color(0xFFF59E0B) : AppTheme.primaryTeal,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: _isPrivateComment ? const Color(0xFFF59E0B) : AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

