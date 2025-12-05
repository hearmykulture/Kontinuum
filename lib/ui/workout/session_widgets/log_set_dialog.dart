import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String kLogSetHeroTag = 'logSetHeroBubble';

// Brand
const Color _kGreen = Color(0xFF22C55E);
const Color _kGreenShadow = Color(0x3322C55E);
const Color _kSurface = Colors.white;

/// Returned when user confirms a set.
class LoggedSet {
  final double loadLb;
  final int reps;
  const LoggedSet(this.loadLb, this.reps);
}

/// Transparent, no-dim route. We animate our own rect.
class HeroDialogRoute<T> extends PageRoute<T> {
  HeroDialogRoute({required this.builder});
  final WidgetBuilder builder;

  @override
  Color get barrierColor => Colors.transparent; // no darkening
  @override
  bool get barrierDismissible => false;
  @override
  String get barrierLabel => 'Dismiss';
  @override
  bool get opaque => false;
  @override
  bool get maintainState => true;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(
          BuildContext context, Animation<double> a, Animation<double> b) =>
      builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeInQuad,
      ),
      child: child,
    );
  }
}

/// Entry that finds the source rect of the button and animates from it.
class LogSetBubble extends StatelessWidget {
  const LogSetBubble({
    super.key,
    required this.heroTag,
    required this.defaultLoadLb,
    required this.defaultReps,
  });

  final String heroTag;
  final double defaultLoadLb;
  final int defaultReps;

  Rect? _findHeroRectGlobal(BuildContext context, Object tag) {
    final overlayState = Overlay.of(context, rootOverlay: true);
    if (overlayState == null) return null;

    final Element root = overlayState.context as Element;
    Element? match;
    void visit(Element e) {
      final w = e.widget;
      if (w is Hero && w.tag == tag) match = e;
      e.visitChildren(visit);
    }

    root.visitChildren(visit);
    if (match == null) return null;

    final ro = match!.renderObject;
    if (ro is! RenderBox) return null;

    final RenderBox box = ro;
    final Offset topLeft = box.localToGlobal(Offset.zero); // global coords
    final Size size = box.size;
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height);
  }

  @override
  Widget build(BuildContext context) {
    final Rect? sourceRect = _findHeroRectGlobal(context, heroTag);
    return _RectPopup(
      sourceRect: sourceRect,
      defaultLoadLb: defaultLoadLb,
      defaultReps: defaultReps,
    );
  }
}

/// Rect popup that grows from the button rect to a target rect (centered)
class _RectPopup extends StatefulWidget {
  const _RectPopup({
    required this.sourceRect,
    required this.defaultLoadLb,
    required this.defaultReps,
  });

  final Rect? sourceRect;
  final double defaultLoadLb;
  final int defaultReps;

  @override
  State<_RectPopup> createState() => _RectPopupState();
}

class _RectPopupState extends State<_RectPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;
  late final Animation<double> _contentOpacity;

  late double _lb = _roundLoad(widget.defaultLoadLb);
  late int _reps = widget.defaultReps;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _t = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _contentOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.55, 1, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close([LoggedSet? res]) async {
    await _ctrl.reverse();
    if (!mounted) return;
    Navigator.of(context).pop<LoggedSet?>(res);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final Size screen = media.size;

    // Compact popup — responsive, and we also scale inner UI if the rect is short.
    final double maxW = math.min(screen.width - 32, 400);
    final double baseHeight = 300;
    final double maxH = math.min(screen.height - 32, baseHeight);

    final Rect targetRect = Rect.fromCenter(
      center: Offset(screen.width / 2, screen.height / 2),
      width: maxW,
      height: maxH,
    );

    // If we couldn't find the source rect, start centered at 80% size
    final Rect fallbackSource = Rect.fromCenter(
      center: targetRect.center,
      width: targetRect.width * 0.8,
      height: targetRect.height * 0.8,
    );

    return Stack(
      children: [
        // Tap-through background that dismisses (no darkening)
        // ✅ Always allow outside-tap to close; our route content fills the screen.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // absorb taps outside the bubble
            child: const SizedBox.expand(),
          ),
        ),

        // Animated box from the EXACT button rect → target
        AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final Rect begin = widget.sourceRect ?? fallbackSource;
            final Rect rect = Rect.lerp(begin, targetRect, _t.value)!;

            return Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: Material(
                color: _kGreen,
                elevation: 12,
                shadowColor: _kGreenShadow,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: _t.value < 0.55
                    ? const Center(
                        child: Text(
                          'Log set',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                      )
                    : Opacity(
                        opacity: _contentOpacity.value,
                        child: _WhiteContent(
                          loadLb: _lb,
                          reps: _reps,
                          onLoadChanged: (v) => setState(() => _lb = v),
                          onRepsChanged: (v) => setState(() => _reps = v),
                          onCancel: () => _close(),
                          onSave: () => _close(
                            LoggedSet(_lb, _reps),
                          ),
                        ),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }

  double _roundLoad(double value) {
    const double inc = 2.5;
    final double normalized =
        (value / inc).round().toDouble() * inc;
    return normalized.clamp(0, 2000);
  }
}

/* ──────────────────────────────────────────────────────────────
   Compact white-on-green content (no scrolling; height-adaptive)
   ────────────────────────────────────────────────────────────── */

class _WhiteContent extends StatefulWidget {
  const _WhiteContent({
    required this.loadLb,
    required this.reps,
    required this.onLoadChanged,
    required this.onRepsChanged,
    required this.onCancel,
    required this.onSave,
  });

  final double loadLb;
  final int reps;
  final ValueChanged<double> onLoadChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  State<_WhiteContent> createState() => _WhiteContentState();
}

class _WhiteContentState extends State<_WhiteContent> {
  late TextEditingController _loadCtl;
  late TextEditingController _repsCtl;

  static String _fmtLoad(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  @override
  void initState() {
    super.initState();
    _loadCtl =
        TextEditingController(text: _fmtLoad(_roundLoad(widget.loadLb)));
    _repsCtl = TextEditingController(text: widget.reps.toString());
  }

  @override
  void didUpdateWidget(covariant _WhiteContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loadLb != oldWidget.loadLb &&
        _fmtLoad(_roundLoad(widget.loadLb)) != _loadCtl.text) {
      _loadCtl.text = _fmtLoad(_roundLoad(widget.loadLb));
    }
    if (widget.reps != oldWidget.reps &&
        widget.reps.toString() != _repsCtl.text) {
      _repsCtl.text = widget.reps.toString();
    }
  }

  double _roundLoad(double value) {
    const double inc = 2.5;
    final double normalized =
        (value / inc).round().toDouble() * inc;
    return normalized.clamp(0, 2000);
  }

  double _parseLoad(String s) {
    final double v = double.tryParse(s.replaceAll(',', '.')) ?? widget.loadLb;
    return _roundLoad(v);
  }

  int _parseReps(String s) {
    final v = int.tryParse(s) ?? widget.reps;
    return v.clamp(0, 200).toInt();
  }

  @override
  void dispose() {
    _loadCtl.dispose();
    _repsCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final double designHeight = 300;
      final double h = c.maxHeight.isFinite ? c.maxHeight : designHeight;
      final double s = (h / designHeight).clamp(0.5, 1.0);

      final double gapS = 8 * s;
      final double gapM = 12 * s;
      final double btnSize = 34 * s;
      final double pillFont = 16 * s;
      final double titleSize = 18 * s;
      final double labelSize = 13 * s;
      final double actionH = math.max(32, 40 * s);

      return SizedBox(
        height: h,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
          child: Column(
            children: [
              Text(
                'Confirm set',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: gapS),
              const Spacer(),
              _CenteredStepper(
                label: 'Load',
                labelSize: labelSize,
                valuePill: _LoadPill(
                  controller: _loadCtl,
                  fontSize: pillFont,
                  width: 120 * s,
                  onSubmitted: (txt) {
                    final double v = _parseLoad(txt);
                    _loadCtl.text = _fmtLoad(v);
                    widget.onLoadChanged(v);
                  },
                  onChanged: (txt) {
                    final double v = _parseLoad(txt);
                    widget.onLoadChanged(v);
                  },
                ),
                onMinus: () {
                  final double v = _roundLoad(_parseLoad(_loadCtl.text) - 5);
                  _loadCtl.text = _fmtLoad(v);
                  widget.onLoadChanged(v);
                },
                onPlus: () {
                  final double v = _roundLoad(_parseLoad(_loadCtl.text) + 5);
                  _loadCtl.text = _fmtLoad(v);
                  widget.onLoadChanged(v);
                },
                buttonSize: btnSize,
                spacing: gapM,
              ),
              SizedBox(height: gapM),
              _CenteredStepper(
                label: 'Reps',
                labelSize: labelSize,
                valuePill: _RepsPill(
                  controller: _repsCtl,
                  fontSize: pillFont,
                  width: 64 * s,
                  onSubmitted: (txt) {
                    final int v = _parseReps(txt);
                    _repsCtl.text = v.toString();
                    widget.onRepsChanged(v);
                  },
                  onChanged: (txt) {
                    final int v = _parseReps(txt);
                    widget.onRepsChanged(v);
                  },
                ),
                onMinus: () {
                  final int v =
                      (_parseReps(_repsCtl.text) - 1).clamp(0, 200).toInt();
                  _repsCtl.text = v.toString();
                  widget.onRepsChanged(v);
                },
                onPlus: () {
                  final int v =
                      (_parseReps(_repsCtl.text) + 1).clamp(0, 200).toInt();
                  _repsCtl.text = v.toString();
                  widget.onRepsChanged(v);
                },
                buttonSize: btnSize,
                spacing: gapM,
              ),
              SizedBox(height: gapM),
              SizedBox(
                height: actionH,
                child: Row(
                  children: [
                    Expanded(
                      child: _WhiteButton(
                        label: 'Cancel',
                        onTap: widget.onCancel,
                      ),
                    ),
                    SizedBox(width: gapS),
                    Expanded(
                      child: _WhiteButton(
                        label: 'Save set',
                        onTap: widget.onSave,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/* ──────────────────────────────────────────────────────────────
   Controls
   ────────────────────────────────────────────────────────────── */

class _CenteredStepper extends StatelessWidget {
  const _CenteredStepper({
    required this.label,
    required this.valuePill,
    required this.onMinus,
    required this.onPlus,
    this.buttonSize = 36,
    this.spacing = 12,
    this.labelSize = 13,
  });

  final String label;
  final Widget valuePill;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final double buttonSize;
  final double spacing;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: labelSize,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: spacing * 0.45),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconCircleButton(
              size: buttonSize,
              icon: Icons.remove_rounded,
              onTap: onMinus,
            ),
            SizedBox(width: spacing),
            valuePill,
            SizedBox(width: spacing),
            _IconCircleButton(
              size: buttonSize,
              icon: Icons.add_rounded,
              onTap: onPlus,
            ),
          ],
        ),
      ],
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.icon,
    required this.onTap,
    this.size = 36,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child:
              Icon(icon, size: math.max(18, size * 0.56), color: Colors.white),
        ),
      ),
    );
  }
}

/// Editable load pill (decimal allowed)
class _LoadPill extends StatelessWidget {
  const _LoadPill({
    required this.controller,
    required this.onSubmitted,
    required this.fontSize,
    required this.width,
    this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final double fontSize;
  final double width;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _EditablePill(
      controller: controller,
      fontSize: fontSize,
      width: width,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
      ],
      suffix: ' lb',
      onSubmitted: onSubmitted,
      onChanged: onChanged,
    );
  }
}

/// Editable reps pill (integers only)
class _RepsPill extends StatelessWidget {
  const _RepsPill({
    required this.controller,
    required this.onSubmitted,
    required this.fontSize,
    required this.width,
    this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final double fontSize;
  final double width;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _EditablePill(
      controller: controller,
      fontSize: fontSize,
      width: width,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: onSubmitted,
      onChanged: onChanged,
    );
  }
}

class _EditablePill extends StatelessWidget {
  const _EditablePill({
    required this.controller,
    required this.fontSize,
    required this.width,
    required this.keyboardType,
    required this.inputFormatters,
    this.suffix,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final double fontSize;
  final double width; // finite width to avoid InputDecorator assertion
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final String? suffix;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            // gives the TextField bounded width
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
              ),
              onSubmitted: onSubmitted,
              onChanged: onChanged,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 6),
            Text(
              suffix!,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: fontSize * 0.85,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({
    required this.label,
    this.onTap,
  });
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool canTap = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: canTap
                ? _kSurface
                : _kSurface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: _kGreen.withValues(alpha: canTap ? 1.0 : 0.4),
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
