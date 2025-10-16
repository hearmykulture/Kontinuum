// lib/ui/widgets/objective/tally_stepper.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A small animated stepper for integer amounts with:
/// - Haptics + system click on taps
/// - Shake + red flash + "-0" bubble when trying to go below min
/// - Ripple outline ring
/// - Quick flash overlay
/// - Floating "+1"/"-1" bubble on tap
/// - Target crossing feedback: medium haptic, ring, green flash when > target
class TallyStepper extends StatefulWidget {
  const TallyStepper({
    super.key,
    required this.amount,
    required this.onChanged,
    this.min = 0,
    this.max = 1 << 31,
    this.target, // optional: when provided, crossing triggers haptics & ring
    this.rowHeight = 36.0,
    this.numberFontSize = 16.0,
    this.radius = 18.0,
    this.backgroundColor = const Color(0x1AFFFFFF),
    this.textColor = Colors.white,
  });

  final int amount;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// Optional threshold like OG "target"; effects trigger when crossing it.
  final int? target;

  /// Visual tweaks (replaces external tokens to keep this file self-contained)
  final double rowHeight; // height for the control
  final double numberFontSize; // font size for the numeric label
  final double radius; // corner radius for overlays/ring
  final Color backgroundColor; // base bg behind the row
  final Color textColor;

  @override
  State<TallyStepper> createState() => _TallyStepperState();
}

class _TallyStepperState extends State<TallyStepper>
    with TickerProviderStateMixin {
  // Subtle bump (scale)
  late final AnimationController _pulse; // 0..0.06
  // Ripple outline ring
  late final AnimationController _ring; // 0..1
  // Floating bubble
  late final AnimationController _bubble; // 0..1
  // Flash overlay
  late final AnimationController _flash; // 0..1
  Color _flashColor = Colors.transparent;

  // Horizontal shake for boundary errors
  late final AnimationController _shakeCtrl; // 0..1

  int _lastDelta = 0; // +1 / -1 for bubble text
  String? _bubbleTextOverride; // to show "-0" when at min

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.0,
      upperBound: 0.06,
    );
    _ring =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) _ring.value = 0;
        });
    _bubble =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) _bubble.value = 0;
        });
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _ring.dispose();
    _bubble.dispose();
    _flash.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _startBubble(int signedDelta, {String? overrideText}) {
    _lastDelta = signedDelta.sign; // normalize to +1 / -1
    _bubbleTextOverride = overrideText; // may be null
    _bubble
      ..stop()
      ..reset()
      ..forward();
  }

  void _triggerFlash(Color color) {
    if (!mounted) return;
    setState(() => _flashColor = color);
    _flash
      ..stop()
      ..reset()
      ..forward();
  }

  void _shake() {
    _shakeCtrl
      ..stop()
      ..reset()
      ..forward();
  }

  void _setAmount(int newAmount, {required int current}) {
    // Always give basic feedback on taps
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);

    final intendedDelta = newAmount - current;

    // Attempt to go below minimum
    if (intendedDelta < 0 && current <= widget.min) {
      _startBubble(-1, overrideText: '-0'); // show “-0” at min
      _triggerFlash(Colors.redAccent); // red flash
      _shake(); // shake the pill
      HapticFeedback.heavyImpact(); // strong haptic
      _pulse
        ..forward(from: 0)
        ..reverse(); // subtle scale bump
      return; // <- do NOT call onChanged
    }

    // Clamp and update
    int clamped = newAmount;
    if (clamped < widget.min) clamped = widget.min;
    if (clamped > widget.max) clamped = widget.max;

    widget.onChanged(clamped);

    // Animations
    _pulse
      ..forward(from: 0)
      ..reverse();
    _startBubble(intendedDelta);

    // Target crossing & over-target behavior (on increments)
    if (intendedDelta > 0 && widget.target != null) {
      final t = widget.target!;
      final crossedTarget = current < t && clamped >= t;
      final isOver = clamped > t;

      if (crossedTarget) HapticFeedback.mediumImpact();
      if (isOver) _triggerFlash(Colors.greenAccent);
      if (clamped >= t) _ring.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.amount;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _ring, _bubble, _flash, _shakeCtrl]),
      builder: (context, _) {
        final scale = 1.0 + _pulse.value;
        final flashOpacity = (1 - _flash.value) * 0.28;

        // Shake offset: decays over time with a sine wave
        final t = _shakeCtrl.value; // 0..1
        final dx = (1 - t) * math.sin(t * math.pi * 10) * 8; // ~8px max

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Base pill
              Transform.scale(
                scale: scale,
                child: Container(
                  height: widget.rowHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(widget.radius),
                    border: Border.all(color: Colors.white12, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Decrease',
                        onPressed: () =>
                            _setAmount(amount - 1, current: amount),
                        icon: const Icon(Icons.remove, size: 20),
                        color: widget.textColor,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: 36,
                          height: widget.rowHeight,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),

                      // Animated number
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.88,
                              end: 1.0,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          '$amount',
                          key: ValueKey(amount),
                          style: TextStyle(
                            color: widget.textColor,
                            fontWeight: FontWeight.w400,
                            fontSize: widget.numberFontSize,
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      IconButton(
                        tooltip: 'Increase',
                        onPressed: () =>
                            _setAmount(amount + 1, current: amount),
                        icon: const Icon(Icons.add, size: 20),
                        color: widget.textColor,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: 36,
                          height: widget.rowHeight,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),

              // Flash overlay (green/red), fades out
              if (flashOpacity > 0.001)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _flashColor.withOpacity(flashOpacity),
                        borderRadius: BorderRadius.circular(widget.radius),
                      ),
                    ),
                  ),
                ),

              // Expanding neutral ring overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: RipplePainter(
                      progress: _ring.value,
                      rrectRadius: widget.radius,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Floating bubble: "+1 / -1" normally, "-0" at min boundary
              if (_bubble.isAnimating || _bubble.value > 0.0)
                IgnorePointer(
                  child: Opacity(
                    opacity: Curves.easeOutQuad.transform(
                      1 - (_bubble.value * 0.9),
                    ),
                    child: Transform.translate(
                      offset: Offset(0, -16 * _bubble.value),
                      child: Text(
                        _bubbleTextOverride ?? (_lastDelta >= 0 ? '+1' : '-1'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Simple rounded-rect ripple ring painter (outline grows over time).
class RipplePainter extends CustomPainter {
  RipplePainter({
    required this.progress, // 0..1
    required this.rrectRadius,
    required this.color,
  });

  final double progress;
  final double rrectRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // Outer rounded rect
    final base = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(rrectRadius),
    );

    // Inflate/deflate to create a moving ring
    final inset = 2 + 10 * progress;
    final ring = base.deflate(inset.clamp(0, base.middleRect.shortestSide / 2));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + 2 * progress
      ..color = color.withOpacity((1 - progress).clamp(0.0, 1.0) * 0.35);

    canvas.drawRRect(ring, paint);
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rrectRadius != rrectRadius ||
        oldDelegate.color != color;
  }
}
