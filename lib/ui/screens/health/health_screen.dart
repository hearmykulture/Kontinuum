// lib/ui/screens/health/health_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Exit',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: const Center(
        child: AnimatedMerkaba(
          size: 260,
          strokeWidth: 4,
          duration: Duration(seconds: 3),
          color: Colors.black,
        ),
      ),
    );
  }
}

class AnimatedMerkaba extends StatefulWidget {
  const AnimatedMerkaba({
    super.key,
    this.size = 240,
    this.strokeWidth = 3,
    this.duration = const Duration(seconds: 3),
    this.color = Colors.black,
    this.autoStart = true,
    this.loop = false,
  });

  final double size;
  final double strokeWidth;
  final Duration duration;
  final Color color;
  final bool autoStart;
  final bool loop;

  @override
  State<AnimatedMerkaba> createState() => _AnimatedMerkabaState();
}

class _AnimatedMerkabaState extends State<AnimatedMerkaba>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    if (widget.autoStart) (widget.loop ? _ctrl.repeat() : _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (_, __) => CustomPaint(
          painter: _MerkabaPainter(
            progress: _curve.value,
            strokeWidth: widget.strokeWidth,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _MerkabaPainter extends CustomPainter {
  _MerkabaPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  final double progress; // 0..1
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // Center & scale
    final c = size.center(Offset.zero);
    canvas.translate(c.dx, c.dy);
    final R = 0.45 * math.min(size.width, size.height); // margin for stroke

    // Six outer vertices (two equilateral triangles, 60° offset)
    Offset polar(double r, double deg) {
      final rad = deg * math.pi / 180.0;
      return Offset(r * math.cos(rad), r * math.sin(rad));
    }

    final top = polar(R, -90);
    final rightTop = polar(R, -30);
    final rightBottom = polar(R, 30);
    final bottom = polar(R, 90);
    final leftBottom = polar(R, 150);
    final leftTop = polar(R, -150);

    // OUTER STAR (two triangles)
    final outer = <_Seg>[
      // Up triangle
      _Seg(top, rightBottom),
      _Seg(rightBottom, leftBottom),
      _Seg(leftBottom, top),
      // Down triangle
      _Seg(bottom, rightTop),
      _Seg(rightTop, leftTop),
      _Seg(leftTop, bottom),
    ];

    // Intersection of downward-triangle sides with the up-triangle base (y = baseY)
    final baseY = leftBottom.dy;

    Offset intersectAtY(Offset p0, Offset p1, double yTarget) {
      final dy = p1.dy - p0.dy;
      if (dy.abs() < 1e-6) return Offset((p0.dx + p1.dx) / 2, yTarget);
      final t = (yTarget - p0.dy) / dy;
      return Offset(p0.dx + (p1.dx - p0.dx) * t, yTarget);
    }

    final leftCross = intersectAtY(leftTop, bottom, baseY);
    final rightCross = intersectAtY(rightTop, bottom, baseY);

    // IMPORTANT: the inner “Y” joint is the centroid of Δ(top, leftCross, rightCross)
    final centroid = Offset(
      (top.dx + leftCross.dx + rightCross.dx) / 3,
      (top.dy + leftCross.dy + rightCross.dy) / 3,
    );

    // INNER LINES matching the reference
    final inner = <_Seg>[
      // Short horizontal base between the two intersections
      _Seg(leftCross, rightCross),
      // The “Y”
      _Seg(centroid, top),
      _Seg(centroid, leftCross),
      _Seg(centroid, rightCross),
    ];

    // Animation timing
    final tOuter = (progress / 0.6).clamp(0.0, 1.0);
    final tInner = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);

    void drawPartial(Offset a, Offset b, double t) {
      if (t <= 0) return;
      final p = Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(p.dx, p.dy);
      canvas.drawPath(path, paint);
    }

    for (final e in outer) {
      drawPartial(e.a, e.b, tOuter);
    }
    for (final e in inner) {
      drawPartial(e.a, e.b, tInner);
    }
  }

  @override
  bool shouldRepaint(covariant _MerkabaPainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.color != color;
}

class _Seg {
  const _Seg(this.a, this.b);
  final Offset a;
  final Offset b;
}
