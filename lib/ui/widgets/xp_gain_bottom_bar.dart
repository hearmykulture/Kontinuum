import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kontinuum/data/level_utils.dart';

class XpGainBottomBar {
  /// Show a temporary XP bar overlay at the bottom.
  /// The bar animates from [fromXp] to [toXp], holds briefly, then slides away.
  static Future<void> show(
    BuildContext context, {
    required String label,
    required int fromXp,
    required int toXp,
    required Color color,
    Duration holdDuration = const Duration(milliseconds: 1400),
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final completer = Completer<void>();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _XpGainOverlay(
        label: label,
        fromXp: fromXp,
        toXp: toXp,
        color: color,
        holdDuration: holdDuration,
        onDismissed: () {
          if (entry.mounted) entry.remove();
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    overlay.insert(entry);
    return completer.future;
  }
}

class _XpGainOverlay extends StatefulWidget {
  const _XpGainOverlay({
    required this.label,
    required this.fromXp,
    required this.toXp,
    required this.color,
    required this.holdDuration,
    required this.onDismissed,
  });

  final String label;
  final int fromXp;
  final int toXp;
  final Color color;
  final Duration holdDuration;
  final VoidCallback onDismissed;

  @override
  State<_XpGainOverlay> createState() => _XpGainOverlayState();
}

class _XpGainOverlayState extends State<_XpGainOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _inOut; // slide / fade in & out
  late final AnimationController _count; // XP count tween
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  late final Animation<int> _xp;

  @override
  void initState() {
    super.initState();

    // Appear/disappear
    _inOut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _inOut, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _inOut, curve: Curves.easeOutCubic));

    // XP animation: duration scales with delta
    final delta = (widget.toXp - widget.fromXp).clamp(0, 100000);
    final ms = (delta * 10).clamp(500, 1600); // ~10ms/xp, clamped
    _count = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    );
    _xp = IntTween(
      begin: widget.fromXp,
      end: widget.toXp,
    ).animate(CurvedAnimation(parent: _count, curve: Curves.easeOutCubic));

    _run();
  }

  Future<void> _run() async {
    try {
      await _inOut.forward(); // slide/fade in
      await _count.forward(); // count/level progress
      await Future.delayed(widget.holdDuration); // hold visible
      await _inOut.reverse(); // slide/fade out
    } finally {
      if (mounted) widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _inOut.dispose();
    _count.dispose();
    super.dispose();
  }

  double _progressWithinLevel(int xp) {
    final lvl = LevelUtils.getCategoryLevelFromXp(xp);
    final low = LevelUtils.getXpForCategoryLevel(lvl);
    final high = LevelUtils.getXpForCategoryLevel(lvl + 1);
    if (high <= low) return 0.0;
    return ((xp - low) / (high - low)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return IgnorePointer(
      ignoring: true, // let touches pass through
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8 + safeBottom),
            child: SlideTransition(
              position: _offset,
              child: FadeTransition(
                opacity: _opacity,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_xp, _inOut]),
                  builder: (_, __) {
                    final shownXp = _xp.value;
                    final lvl = LevelUtils.getCategoryLevelFromXp(shownXp);
                    final next = LevelUtils.getXpForCategoryLevel(lvl + 1);
                    final progress = _progressWithinLevel(shownXp);

                    return _BottomCard(
                      color: widget.color,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Level $lvl: ${widget.label}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: widget.color,
                              fontSize: 14,
                              decoration:
                                  TextDecoration.none, // no yellow lines
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: Colors.white10,
                              color: widget.color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "$shownXp / $next XP",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: widget.color.withOpacity(0.85),
                              fontSize: 12,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomCard extends StatelessWidget {
  final Color color;
  final Widget child;
  const _BottomCard({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141622).withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.65), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.32),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
