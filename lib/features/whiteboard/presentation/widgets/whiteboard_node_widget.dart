import 'package:flutter/material.dart';
import '../../models/whiteboard_model.dart';

class WhiteboardNodeWidget extends StatelessWidget {
  final WhiteboardNode node;
  final bool isSelected;
  final bool canDrag;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;

  const WhiteboardNodeWidget({
    super.key,
    required this.node,
    required this.isSelected,
    required this.canDrag,
    required this.onTap,
    required this.onDoubleTap,
    required this.onDragStart,
    required this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Color(node.colorValue);

    final BorderRadius borderRadius = switch (node.shape) {
      WhiteboardNodeShape.pill => BorderRadius.circular(40),
      WhiteboardNodeShape.diamond => BorderRadius.circular(6),
      WhiteboardNodeShape.rounded => BorderRadius.circular(16),
    };

    return Positioned(
      left: node.x,
      top: node.y,
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onPanStart: canDrag ? (_) => onDragStart() : null,
        onPanUpdate: canDrag ? (details) => onDragUpdate(details.delta) : null,
        child: Container(
          width: node.width,
          constraints: BoxConstraints(minHeight: node.height),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: borderRadius,
            border: Border.all(
              color: isSelected
                  ? accent
                  : accent.withValues(alpha: isDark ? 0.65 : 0.45),
              width: isSelected ? 2.6 : 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: (isSelected ? accent : Colors.black)
                    .withValues(alpha: isSelected ? 0.22 : 0.08),
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                node.title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (node.subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  node.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? Colors.grey.shade300
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
