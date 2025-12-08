// lib/ui/widgets/objective/stat_progress.dart
import 'package:flutter/material.dart';
import 'package:kontinuum/data/level_utils.dart';

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

  // Progress within the *current* level window (0..1)
  double _progressFor(int xp) {
    final lp = _levelData(xp);
    final frac = lp.progress.clamp(0.0, 1.0);
    if (frac.isNaN || frac.isInfinite) return 0.0;
    return frac;
  }

  // 0-based index of the level window you’re in
  int _levelIndex(int xp) {
    final lp = _levelData(xp);
    return (lp.level.clamp(1, LevelUtils.maxLevel) - 1);
  }

  LevelProgress _levelData(int xp) {
    final cap = widget.maxXp <= 0 ? 1 : widget.maxXp;
    return LevelUtils.getProgress(xp: xp, maxXp: cap);
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

    setState(() {
      _visual = from.clamp(0.0, 1.0);
    });

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
    final segments = _progressSegments(prevXp, currXp);
    final target = _progressFor(currXp);
    if (segments.isEmpty) {
      setState(() => _visual = target);
      return;
    }

    // Helper to bail if a newer sequence starts
    Future<bool> guard(Future<void> f) async {
      await f;
      return _seq == runId;
    }

    for (final segment in segments) {
      try {
        final ok = await guard(
          _animateSegment(
            from: segment.from,
            to: segment.to,
            duration: _durForDelta(segment.to - segment.from),
          ),
        );
        if (!ok) {
          setState(() => _visual = target);
          return;
        }
      } catch (_) {
        if (_seq != runId) return;
      }
    }

    // Ensure final visual matches the target progress even if animations bailed early.
    if (_visual != target && _seq == runId) {
      setState(() => _visual = target);
    }
  }

  List<_ProgressSegment> _progressSegments(int prevXp, int currXp) {
    final prevLevel = _levelIndex(prevXp);
    final currLevel = _levelIndex(currXp);
    final start = _progressFor(prevXp);
    final end = _progressFor(currXp);
    final segments = <_ProgressSegment>[];

    void add(double from, double to) {
      final a = from.clamp(0.0, 1.0).toDouble();
      final b = to.clamp(0.0, 1.0).toDouble();
      if ((a - b).abs() < 0.0001) return;
      segments.add(_ProgressSegment(a, b));
    }

    if (currLevel == prevLevel) {
      add(start, end);
      return segments;
    }

    if (currLevel > prevLevel) {
      add(start, 1.0);
      for (int level = prevLevel + 1; level < currLevel; level++) {
        add(0.0, 1.0);
      }
      add(0.0, end);
      return segments;
    }

    add(start, 0.0);
    for (int level = prevLevel - 1; level > currLevel; level--) {
      add(1.0, 0.0);
    }
    add(1.0, end);
    return segments;
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
    required this.xpIntoLevel,
    required this.levelSpan,
    required this.color,
  });

  final int level;
  final int xpIntoLevel; // xp within the current level window
  final int levelSpan; // xp needed for this level
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safeSpan = levelSpan <= 0 ? 1 : levelSpan;
    final left = "$xpIntoLevel / $safeSpan XP";
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          left,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}

class _ProgressSegment {
  final double from;
  final double to;

  const _ProgressSegment(this.from, this.to);
}
