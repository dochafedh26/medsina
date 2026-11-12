import 'dart:math';
import 'package:flutter/material.dart';

/// Native zero-dependency confetti celebration overlay for daily goals & milestones.
class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final Duration duration;

  const ConfettiOverlay({
    super.key,
    required this.child,
    this.trigger = false,
    this.duration = const Duration(milliseconds: 2200),
  });

  /// Shows a non-blocking confetti burst above the current Navigator overlay.
  static void show(BuildContext context) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: _ConfettiBurstLayer(
          onComplete: () {
            if (entry.mounted) {
              entry.remove();
            }
          },
        ),
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> {
  bool _showing = false;

  @override
  void didUpdateWidget(covariant ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      setState(() => _showing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showing)
          Positioned.fill(
            child: IgnorePointer(
              child: _ConfettiBurstLayer(
                duration: widget.duration,
                onComplete: () {
                  if (mounted) setState(() => _showing = false);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiBurstLayer extends StatefulWidget {
  final Duration duration;
  final VoidCallback onComplete;

  const _ConfettiBurstLayer({
    this.duration = const Duration(milliseconds: 2200),
    required this.onComplete,
  });

  @override
  State<_ConfettiBurstLayer> createState() => _ConfettiBurstLayerState();
}

class _ConfettiBurstLayerState extends State<_ConfettiBurstLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    const palette = [
      Color(0xFF0D9488),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF38BDF8),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
    ];
    _particles = List.generate(55, (i) {
      return _ConfettiParticle(
        x: rng.nextDouble(),
        startY: -0.05 - rng.nextDouble() * 0.25,
        speedY: 0.75 + rng.nextDouble() * 0.85,
        driftX: (rng.nextDouble() - 0.5) * 0.25,
        size: 6 + rng.nextDouble() * 7,
        rotationSpeed: (rng.nextDouble() - 0.5) * 10,
        color: palette[i % palette.length],
        isCircle: i % 3 == 0,
      );
    });

    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ConfettiPainter(
            progress: _controller.value,
            particles: _particles,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double startY;
  final double speedY;
  final double driftX;
  final double size;
  final double rotationSpeed;
  final Color color;
  final bool isCircle;

  const _ConfettiParticle({
    required this.x,
    required this.startY,
    required this.speedY,
    required this.driftX,
    required this.size,
    required this.rotationSpeed,
    required this.color,
    required this.isCircle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = (1.0 - Curves.easeIn.transform(progress)).clamp(0.0, 1.0);
    for (final p in particles) {
      final dx = (p.x + p.driftX * progress) * size.width;
      final dy = (p.startY + p.speedY * progress) * size.height;
      if (dy < -20 || dy > size.height + 20) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotationSpeed * progress);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
