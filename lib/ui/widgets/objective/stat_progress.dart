// lib/ui/widgets/objective/stat_progress.dart
import 'package:flutter/material.dart';

/// Wrap-aware progress bar that animates smoothly within the current
/// "level window" and across level boundaries.
/// - previousXp/currentXp: source values to animate between
/// - maxXp: total cap (used to derive 100 equal "levels")
/// - color/backgroundColor/thickness: styling
class LevelProgressBar extends StatefulWidget {
  const LevelProgressBar({
    Key? key,
    required this.previousXp,
    required this.currentXp,
    required this.maxXp,
    required this.color,
    this.backgroundColor = const Color(0xFF141622),
    this.thickness = 7.5,
  }) : super(key: key);

  final int previousXp;
  final int currentXp;
  final int maxXp;
  final Color color;
  final Color backgroundColor;
  final double thickness;

  @override
  State<LevelProgressBar> createState() => _LevelProgressBarState();
}

class _LevelProgressBarState extends State<LevelProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;

  // Visual progress in the current level window (0..1)
  double _visual = 0.0;

  // Sequence token to cancel in-flight animation chains when props change.
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _visual = _progressFor(widget.currentXp);
  }

  @override
  void didUpdateWidget(covariant LevelProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentXp != oldWidget.currentXp ||
        widget.maxXp != oldWidget.maxXp ||
        widget.previousXp != oldWidget.previousXp) {
      _animateFromTo(widget.previousXp, widget.currentXp);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // xp-per-level (100 equal slices of maxXp; guard zero)
  double _perLevel() {
    final mx = widget.maxXp <= 0 ? 1 : widget.maxXp;
    return mx / 100.0;
  }

  // Progress within the *current* level window (0..1)
  double _progressFor(int xp) {
    final step = _perLevel();
    if (step <= 0) return 0.0;

    // Display level 1..100
    final lvl =
        ((xp / (widget.maxXp <= 0 ? 1 : widget.maxXp)) * 100).floor().clamp(
          0,
          99,
        ) +
        1;

    final lower = (lvl - 1) * step;
    final prog = (xp - lower) / step; // 0..1 within this level
    final frac = prog.clamp(0.0, 1.0);
    if (frac.isNaN || frac.isInfinite) return 0.0;
    return frac;
  }

  // 0-based index of the level window you’re in
  int _levelIndex(int xp) {
    final step = _perLevel();
    if (step <= 0) return 0;
    return (xp / step).floor().clamp(0, 99);
  }

  Duration _durForDelta(double delta) {
    final d = delta.abs().clamp(0.0, 1.0);
    final ms = (250 + 550 * d).clamp(160, 800).toInt();
    return Duration(milliseconds: ms);
  }

  Future<void> _animateSegment({
    required double from,
    required double to,
    required Duration duration,
    Curve curve = Curves.easeOutCubic,
  }) async {
    _ctrl.stop();
    _ctrl.duration = duration;

    final anim = Tween<double>(
      begin: from,
      end: to,
    ).animate(CurvedAnimation(parent: _ctrl, curve: curve));
    _anim = anim;

    void tick() {
      setState(() {
        _visual = _anim.value.clamp(0.0, 1.0);
      });
    }

    _ctrl.addListener(tick);
    await _ctrl.forward(from: 0);
    _ctrl.removeListener(tick);
  }

  Future<void> _animateFromTo(int prevXp, int currXp) async {
    final runId = ++_seq;

    final fromProg = _progressFor(prevXp);
    final toProg = _progressFor(currXp);
    final fromLvl = _levelIndex(prevXp);
    final toLvl = _levelIndex(currXp);

    // No change
    if (prevXp == currXp) {
      setState(() => _visual = toProg);
      return;
    }

    // Helper to bail if a newer sequence starts
    Future<void> guard(Future<void> f) async {
      await f;
      if (_seq != runId) {
        throw 'cancelled';
      }
    }

    try {
      if (currXp > prevXp) {
        // FORWARD: fill to 1.0 for each level crossed, then up to toProg
        final levelsCrossed = toLvl - fromLvl;
        if (levelsCrossed <= 0) {
          await guard(
            _animateSegment(
              from: fromProg,
              to: toProg,
              duration: _durForDelta(toProg - fromProg),
            ),
          );
        } else {
          await guard(
            _animateSegment(
              from: fromProg,
              to: 1.0,
              duration: _durForDelta(1.0 - fromProg),
            ),
          );
          for (int i = 0; i < levelsCrossed - 1; i++) {
            if (_seq != runId) throw 'cancelled';
            setState(() => _visual = 0.0);
            await guard(
              _animateSegment(from: 0.0, to: 1.0, duration: _durForDelta(1.0)),
            );
          }
          if (_seq != runId) throw 'cancelled';
          setState(() => _visual = 0.0);
          await guard(
            _animateSegment(
              from: 0.0,
              to: toProg,
              duration: _durForDelta(toProg),
            ),
          );
        }
      } else {
        // BACKWARD: unfill to 0.0 for each level crossed backward, then down to toProg
        final levelsCrossed = fromLvl - toLvl;
        if (levelsCrossed <= 0) {
          await guard(
            _animateSegment(
              from: fromProg,
              to: toProg,
              duration: _durForDelta(toProg - fromProg),
            ),
          );
        } else {
          await guard(
            _animateSegment(
              from: fromProg,
              to: 0.0,
              duration: _durForDelta(fromProg - 0.0),
            ),
          );
          for (int i = 0; i < levelsCrossed - 1; i++) {
            if (_seq != runId) throw 'cancelled';
            setState(() => _visual = 1.0);
            await guard(
              _animateSegment(from: 1.0, to: 0.0, duration: _durForDelta(1.0)),
            );
          }
          if (_seq != runId) throw 'cancelled';
          setState(() => _visual = 1.0);
          await guard(
            _animateSegment(
              from: 1.0,
              to: toProg,
              duration: _durForDelta(1.0 - toProg),
            ),
          );
        }
      }
    } catch (_) {
      // cancelled by a newer sequence — ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: _visual,
      minHeight: widget.thickness,
      backgroundColor: widget.backgroundColor,
      color: widget.color,
    );
  }
}

/// Tiny "xp / next" numbers line used under the mini bar (aligned to bar).
class MiniXpNumbers extends StatelessWidget {
  const MiniXpNumbers({
    super.key,
    required this.level,
    required this.step,
    required this.currentWithin,
    required this.totalMaxXp,
    required this.color,
  });

  final int level; // 1..100
  final int step; // maxXp/100
  final int currentWithin; // xp - lowerBound
  final int totalMaxXp; // total cap (for right side "total")
  final Color color;

  @override
  Widget build(BuildContext context) {
    final left = "$currentWithin / $step XP";
    final right = "${(level - 1) * step + currentWithin} / $totalMaxXp total";
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          left,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.85)),
        ),
        const Text(
          " ",
          style: TextStyle(fontSize: 10, color: Colors.transparent),
        ),
        Text(
          right,
          style: const TextStyle(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }
}
