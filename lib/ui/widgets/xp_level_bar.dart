import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:provider/provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/data/level_utils.dart';

class XpLevelBarController extends ChangeNotifier {
  _XpLevelBarState? _state;
  void _attach(_XpLevelBarState s) => _state = s;
  void _detach(_XpLevelBarState s) {
    if (identical(_state, s)) _state = null;
  }

  /// Jump the bar to [categoryName] (null or "TOTAL" for global)
  /// and animate XP from [fromXp] -> [toXp].
  void jumpToCategoryAndAnimate({
    String? categoryName,
    required int fromXp,
    required int toXp,
  }) {
    _state?._runExternalAnimation(
      categoryName: categoryName,
      fromXp: fromXp,
      toXp: toXp,
    );
  }
}

class XpLevelBar extends StatefulWidget {
  const XpLevelBar({super.key, this.controller, this.onStatsPressed});

  final XpLevelBarController? controller;

  /// When provided, shows a white stats icon to the LEFT of the
  /// "Level X: ..." title (above the progress bar). Tapping the icon
  /// or dragging up on the bar will call this to open Stats.
  final VoidCallback? onStatsPressed;

  @override
  State<XpLevelBar> createState() => _XpLevelBarState();
}

class _XpLevelBarState extends State<XpLevelBar> with TickerProviderStateMixin {
  // -1 = TOTAL, 0+ = per-category index
  int _viewIndex = -1;

  // Animated XP counting
  late final AnimationController _xpAnim;
  Animation<int>? _xpTween; // null when idle

  // Subtle bounce when animating / tapping
  late final AnimationController _bounce;
  late final Animation<double> _bounceScale;

  // Upward-drag → open stats
  double? _dragStartY;
  bool _openedStatsThisDrag = false;
  static const double _kOpenStatsDragThreshold = 36; // px

  static const Color _kTotalColor = Color(0xFFFF4D8D); // TOTAL pink

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);

    _xpAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceScale = Tween<double>(
      begin: 0.98,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(covariant XpLevelBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _xpAnim.dispose();
    _bounce.dispose();
    super.dispose();
  }

  // External trigger from controller
  void _runExternalAnimation({
    String? categoryName,
    required int fromXp,
    required int toXp,
  }) {
    final provider = context.read<ObjectiveProvider>();
    final categories = provider.categories.values.toList();

    int newIndex = -1; // TOTAL by default
    if (categoryName != null && categoryName.toUpperCase() != 'TOTAL') {
      final i = categories.indexWhere(
        (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      );
      if (i != -1) newIndex = i;
    }
    setState(() => _viewIndex = newIndex);

    // Animate XP count
    final delta = (toXp - fromXp).clamp(0, 100000);
    final ms = (delta * 10).clamp(500, 1600);
    _xpAnim.duration = Duration(milliseconds: ms);
    _xpTween =
        IntTween(begin: fromXp, end: toXp).animate(
          CurvedAnimation(parent: _xpAnim, curve: Curves.easeOutCubic),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed && mounted) {
            setState(() => _xpTween = null);
          }
        });

    _xpAnim
      ..stop()
      ..reset()
      ..forward();
    _kickBounce();
  }

  void _kickBounce() {
    _bounce
      ..stop()
      ..reset()
      ..forward();
  }

  Color _colorForCategory(String name) {
    switch (name.toLowerCase()) {
      case 'rapping':
        return Colors.redAccent;
      case 'production':
        return Colors.blueAccent;
      case 'health':
        return Colors.greenAccent;
      case 'knowledge':
        return Colors.deepPurpleAccent;
      case 'networking':
        return Colors.teal;
      case 'content':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  ({int level, double progress, int nextLevelXp}) _deriveFromXp(int xp) {
    final lvl = LevelUtils.getCategoryLevelFromXp(xp);
    final low = LevelUtils.getXpForCategoryLevel(lvl);
    final next = LevelUtils.getXpForCategoryLevel(lvl + 1);
    final range = (next - low);
    final prog = range <= 0 ? 0.0 : ((xp - low) / range).clamp(0.0, 1.0);
    return (level: lvl, progress: prog, nextLevelXp: next);
  }

  // Tap handlers to cycle categories
  void _cycleForward() {
    final provider = context.read<ObjectiveProvider>();
    final catCount = provider.categories.length;
    if (catCount == 0) return;

    setState(() {
      if (_viewIndex == -1) {
        _viewIndex = 0; // TOTAL -> first category
      } else {
        _viewIndex += 1;
        if (_viewIndex >= catCount) _viewIndex = -1; // wrap to TOTAL
      }
    });
    HapticFeedback.selectionClick();
    _kickBounce();
  }

  void _resetToTotal() {
    setState(() => _viewIndex = -1);
    HapticFeedback.selectionClick();
    _kickBounce();
  }

  // ----- Upward-drag detection → open stats -----
  void _onVerticalDragStart(DragStartDetails d) {
    _dragStartY = d.globalPosition.dy;
    _openedStatsThisDrag = false;
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_dragStartY == null || _openedStatsThisDrag) return;
    final deltaUp = _dragStartY! - d.globalPosition.dy; // up = positive
    if (deltaUp > _kOpenStatsDragThreshold) {
      _openedStatsThisDrag = true;
      HapticFeedback.selectionClick();
      widget.onStatsPressed?.call();
    }
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    _dragStartY = null;
    _openedStatsThisDrag = false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ObjectiveProvider>(context);
    final categories = provider.categories.values.toList();

    // Guard against stale index if categories changed
    final int safeIndex = (_viewIndex >= 0 && _viewIndex < categories.length)
        ? _viewIndex
        : -1;

    // Live snapshot for label/color/xp
    String label = "TOTAL";
    Color color = _kTotalColor;
    int liveXp;
    if (safeIndex == -1) {
      liveXp = provider.totalXp;
    } else {
      final cat = categories[safeIndex];
      label = cat.name.toUpperCase();
      color = _colorForCategory(cat.name);
      liveXp = cat.xp;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_xpAnim, _bounce]),
      builder: (_, __) {
        final shownXp = _xpTween?.value ?? liveXp;
        final m = _deriveFromXp(shownXp);

        return Padding(
          // ~10% less vertical padding
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: widget.onStatsPressed == null
                ? null
                : _onVerticalDragStart,
            onVerticalDragUpdate: widget.onStatsPressed == null
                ? null
                : _onVerticalDragUpdate,
            onVerticalDragEnd: widget.onStatsPressed == null
                ? null
                : _onVerticalDragEnd,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                // Invisible ink effects
                borderRadius: BorderRadius.circular(12),
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                overlayColor: MaterialStateProperty.all(Colors.transparent),

                onTap: _cycleForward,
                onLongPress: _resetToTotal,

                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),

                  // 🔑 Only fade when the category index changes (not every XP tick)
                  child: _BarContent(
                    key: ValueKey<int>(safeIndex),
                    color: color,
                    label: label,
                    level: m.level,
                    progress: m.progress,
                    shownXp: shownXp,
                    nextLevelXp: m.nextLevelXp,
                    bounceScale: _bounceScale,
                    onStatsPressed:
                        widget.onStatsPressed, // ← tap icon opens Stats
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarContent extends StatelessWidget {
  const _BarContent({
    super.key,
    required this.color,
    required this.label,
    required this.level,
    required this.progress,
    required this.shownXp,
    required this.nextLevelXp,
    required this.bounceScale,
    this.onStatsPressed,
  });

  final Color color;
  final String label;
  final int level;
  final double progress;
  final int shownXp;
  final int nextLevelXp;
  final Animation<double> bounceScale;

  /// If provided, renders the stats button LEFT of the title (above the bar).
  final VoidCallback? onStatsPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // compact
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Column(
        children: [
          // Title row: icon pinned left, title stays centered.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Text(
                  "Level $level: $label",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ),
              if (onStatsPressed != null)
                Positioned(
                  left: 0,
                  top: -2, // tiny upward nudge
                  bottom: -2,
                  child: _StatsHeaderButton(
                    onPressed: onStatsPressed!, // ← tap -> open Stats
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),

          // Progress bar
          ScaleTransition(
            scale: bounceScale,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade800,
                color: color,
                minHeight: 9,
              ),
            ),
          ),

          const SizedBox(height: 3),
          Text(
            "$shownXp / $nextLevelXp XP",
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.75)),
          ),
          const SizedBox(height: 1),
        ],
      ),
    );
  }
}

class _StatsHeaderButton extends StatelessWidget {
  const _StatsHeaderButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Solid white equalizer icon; slightly larger; keeps tap target compact.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        child: SizedBox(
          width: 32,
          height: 26,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(0, -1.0),
              child: const Icon(
                Icons.equalizer_rounded, // three filled vertical bars
                size: 21,
                color: Colors.white, // solid white, no bg/border
                semanticLabel: 'Stats',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
