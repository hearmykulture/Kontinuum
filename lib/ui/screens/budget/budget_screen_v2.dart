// lib/ui/screens/budget/budget_screen_v2.dart
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:kontinuum/ui/screens/budget/create_budget_screen.dart';
import 'package:kontinuum/ui/screens/budget/models/budget_models.dart';

// 🔧 Debug screen hook
import 'package:kontinuum/ui/screens/banking/banking_debug_screen.dart';

class BudgetScreenV2 extends StatefulWidget {
  const BudgetScreenV2({
    super.key,
    this.onAddPressed,
    this.onGetStarted,
    this.onExpandCompleted,
  });

  final VoidCallback? onAddPressed;
  final VoidCallback? onGetStarted;
  final VoidCallback? onExpandCompleted;

  static const Color kBudgetGreen = Color(0xFF051F20); // page bg
  static const Color kButtonGreen = Color(0xFF0B2B26); // square & expanded
  static const Color kPlusMint = Color(0xFFDAF1DE); // icon & text

  @override
  State<BudgetScreenV2> createState() => _BudgetScreenV2State();
}

class _BudgetScreenV2State extends State<BudgetScreenV2>
    with TickerProviderStateMixin {
  static const double _centerYOffset = -0.10;
  static const double _cornerRadius = 24.0;

  // 🔧 Debug defaults (edit as needed)
  static const String _kDebugBaseUrl = 'http://localhost:4000';
  static const String _kDebugUserId = '9892ccbcfe3a4f79bf02147527c3fb61';

  final GlobalKey _rootStackKey = GlobalKey();

  // Launch sources for nice morph animation
  final GlobalKey _squareKey = GlobalKey();
  final GlobalKey _savedBtnKey = GlobalKey(debugLabel: 'savedBudgetBtn');
  final GlobalKey _createBtnKey = GlobalKey(debugLabel: 'createNewBtn');

  Rect? _startRect;

  // Overlay expand/collapse
  late final AnimationController _expandCtrl;
  static const _curveExpand = Curves.easeInOutCubic;

  // Saved budget (simple in-memory persistence for now)
  BudgetDraft? _lastSavedBudget;
  BudgetDraft? _draftBeingEdited; // null = creating new

  final _money = NumberFormat.currency(symbol: '\$');

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onExpandCompleted?.call();
      });
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  // ---------- Debug: open banking screen ----------
  void _openBankingDebug() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BankingDebugScreen(
          userId: _kDebugUserId,
          defaultBaseUrl: _kDebugBaseUrl,
        ),
      ),
    );
  }

  // -------- Launch / close helpers --------
  void _captureRectFrom(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final root = _rootStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && root != null) {
      final topLeft = box.localToGlobal(Offset.zero, ancestor: root);
      final size = box.size;
      setState(() {
        _startRect =
            Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height);
      });
    }
  }

  void _openFrom(GlobalKey key, {BudgetDraft? initial}) {
    HapticFeedback.selectionClick();
    widget.onAddPressed?.call();
    _draftBeingEdited = initial; // null = create new
    _captureRectFrom(key);
    if (_expandCtrl.isDismissed) _expandCtrl.forward();
  }

  void _onPlusPressed() {
    _openFrom(_squareKey, initial: null);
  }

  void _openSavedPressed() {
    if (_lastSavedBudget == null) return;
    _openFrom(_savedBtnKey, initial: _lastSavedBudget);
  }

  void _openCreateNewPressed() {
    _openFrom(_createBtnKey, initial: null);
  }

  void _closeExpanded() {
    HapticFeedback.selectionClick();
    if (_expandCtrl.value > 0.0) _expandCtrl.reverse();
  }

  void _handleBudgetSaved(BudgetDraft draft) {
    setState(() => _lastSavedBudget = draft); // "save"
    _closeExpanded();
  }

  bool get _hasSaved => _lastSavedBudget != null;

  @override
  Widget build(BuildContext context) {
    final headerCloseOpacity = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _expandCtrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeInOut),
      ),
    );

    final Animation<double> plusOpacity = ReverseAnimation(
      CurvedAnimation(
        parent: _expandCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    return AnimatedBuilder(
      animation: _expandCtrl,
      builder: (_, __) {
        final bool fullyExpanded =
            _expandCtrl.status == AnimationStatus.completed ||
                _expandCtrl.value > 0.999;
        final Color scaffoldBg = fullyExpanded
            ? BudgetScreenV2.kButtonGreen
            : BudgetScreenV2.kBudgetGreen;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: scaffoldBg,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: scaffoldBg,
            body: Stack(
              key: _rootStackKey,
              children: [
                // Foreground content that gets overtaken (no fade)
                SafeArea(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          // 🔧 Long-press "Budgets" to open BankingDebugScreen
                          child: GestureDetector(
                            onLongPress: _openBankingDebug,
                            child: const Text(
                              'Budgets',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Page-level X — fades OUT while expanding
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IgnorePointer(
                          ignoring: headerCloseOpacity.value < 0.05,
                          child: FadeTransition(
                            opacity: headerCloseOpacity,
                            child: _CloseButton(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.of(context).maybePop();
                              },
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, _centerYOffset),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_hasSaved) ...[
                              _GetStartedButton(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  widget.onGetStarted?.call();
                                },
                              ),
                              const SizedBox(height: 18),
                              _AddSquare(
                                measureKey: _squareKey,
                                size: 150,
                                onTap: _onPlusPressed,
                                plusOpacity: plusOpacity,
                                cornerRadius: _cornerRadius,
                              ),
                            ] else ...[
                              _ActionButton(
                                key: _savedBtnKey,
                                label: 'Open "${_lastSavedBudget!.title}"',
                                subtitle:
                                    'Monthly: ${_money.format(_lastSavedBudget!.monthlyAmount)}',
                                icon: Icons.folder_open_rounded,
                                onTap: _openSavedPressed,
                              ),
                              const SizedBox(height: 12),
                              _ActionButton(
                                key: _createBtnKey,
                                label: 'Create new budget',
                                icon: Icons.add_rounded,
                                onTap: _openCreateNewPressed,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Expanding overlay
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final endRect =
                          Rect.fromLTWH(0, 0, c.maxWidth, c.maxHeight);
                      return AnimatedBuilder(
                        animation: _expandCtrl,
                        builder: (_, __) {
                          final v = CurvedAnimation(
                            parent: _expandCtrl,
                            curve: _curveExpand,
                          ).value;

                          if (v <= 0.0 || _startRect == null) {
                            return const SizedBox.shrink();
                          }

                          final Rect r = Rect.lerp(_startRect!, endRect, v)!;

                          final closeOpacity = CurvedAnimation(
                            parent: _expandCtrl,
                            curve: const Interval(0.25, 0.85,
                                curve: Curves.easeInOut),
                          );

                          final bool contentInteractive = v > 0.985;

                          return Stack(
                            children: [
                              Positioned(
                                left: r.left,
                                top: r.top,
                                width: r.width,
                                height: r.height,
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(_cornerRadius),
                                  child: Material(
                                    color: BudgetScreenV2.kButtonGreen,
                                    child: contentInteractive
                                        ? CreateBudgetScreen(
                                            onClose: null, // use overlay X
                                            initial: _draftBeingEdited,
                                            onComplete: _handleBudgetSaved,
                                          )
                                        : const SizedBox.expand(),
                                  ),
                                ),
                              ),
                              SafeArea(
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: IgnorePointer(
                                      ignoring: closeOpacity.value < 0.05,
                                      child: FadeTransition(
                                        opacity: closeOpacity,
                                        child:
                                            _CloseButton(onTap: _closeExpanded),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------- Get Started ----------
class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Get started',
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: BudgetScreenV2.kButtonGreen,
          foregroundColor: BudgetScreenV2.kPlusMint,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: const StadiumBorder(),
        ),
        onPressed: onPressed,
        child: const _FlashText(
          'Get Started',
          color: BudgetScreenV2.kPlusMint,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          period: Duration(seconds: 5),
          flashDuration: Duration(milliseconds: 1300),
          tailPortion: 0.22,
        ),
      ),
    );
  }
}

// ---------- Wide action button ----------
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.icon,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.06)),
          child: Ink(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: BudgetScreenV2.kButtonGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: BudgetScreenV2.kPlusMint),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BudgetScreenV2.kPlusMint,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Add square ----------
class _AddSquare extends StatelessWidget {
  const _AddSquare({
    super.key,
    required this.onTap,
    this.plusOpacity,
    this.size = 150,
    this.cornerRadius = 24,
    this.measureKey,
  });

  final VoidCallback onTap;
  final Animation<double>? plusOpacity;
  final double size;
  final double cornerRadius;
  final GlobalKey? measureKey;

  @override
  Widget build(BuildContext context) {
    final icon =
        const Icon(Icons.add, size: 44, color: BudgetScreenV2.kPlusMint);
    return Semantics(
      label: 'Add',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(cornerRadius),
          overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.06)),
          child: Ink(
            key: measureKey,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: BudgetScreenV2.kButtonGreen,
              borderRadius: BorderRadius.circular(cornerRadius),
            ),
            child: Center(
              child: plusOpacity == null
                  ? icon
                  : FadeTransition(opacity: plusOpacity!, child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Close (X) ----------
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Close',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.08)),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: BudgetScreenV2.kPlusMint.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: const Center(
              child:
                  Icon(Icons.close, size: 20, color: BudgetScreenV2.kPlusMint),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Flash text (unchanged) ----------
class _FlashText extends StatefulWidget {
  const _FlashText(
    this.text, {
    required this.color,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
    this.period = const Duration(seconds: 5),
    this.flashDuration = const Duration(milliseconds: 1300),
    this.tailPortion = 0.20,
    this.peakScale = 1.14,
    this.whiteMix = 0.50,
    this.maxGlow = 12.0,
    this.glowOpacity = 0.50,
    this.margin = 0.14,
    this.sigma = 0.16,
  });

  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final Duration period;
  final Duration flashDuration;
  final double tailPortion;
  final double peakScale;
  final double whiteMix;
  final double maxGlow;
  final double glowOpacity;
  final double margin;
  final double sigma;

  @override
  State<_FlashText> createState() => _FlashTextState();
}

class _FlashTextState extends State<_FlashText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late double _flashPortion;
  late double _tail;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)..repeat();
    _flashPortion =
        widget.flashDuration.inMilliseconds / widget.period.inMilliseconds;
    _tail = widget.tailPortion.clamp(0.05, 0.5);
    if (_flashPortion + _tail > 0.92) {
      _tail = (0.92 - _flashPortion).clamp(0.05, 0.5);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chars = widget.text.split('');
    final letterIdx = <int>[];
    for (int i = 0; i < chars.length; i++) {
      if (chars[i] != ' ') letterIdx.add(i);
    }
    final m = letterIdx.length;
    final xs = List<double>.generate(m, (i) => (m == 1) ? 0.5 : i / (m - 1));

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;

        double? centerX;
        if (t <= _flashPortion) {
          final local = (t / _flashPortion).clamp(0.0, 1.0);
          final eased = Curves.easeInOutCubic.transform(local);
          centerX = -widget.margin + (1 + 2 * widget.margin) * eased;
        }

        double globalTail = 0.0;
        if (t > _flashPortion && t <= (_flashPortion + _tail)) {
          final k = (t - _flashPortion) / _tail;
          globalTail = 0.35 * (1.0 - Curves.easeOutCubic.transform(k));
        }

        int nonSpace = 0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: TextBaseline.alphabetic == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: List.generate(chars.length, (i) {
            final ch = chars[i];
            if (ch == ' ') return const SizedBox(width: 6);

            double intensity = 0.0;
            if (centerX != null) {
              final x = xs[nonSpace];
              final dx = x - centerX;
              final sig2 = 2 * widget.sigma * widget.sigma;
              final gauss = math.exp(-(dx * dx) / sig2).clamp(0.0, 1.0);
              final sweepProg = (t / _flashPortion).clamp(0.0, 1.0);
              final edgeSoft = 0.5 * Curves.easeOut.transform(sweepProg) +
                  0.5 * Curves.easeIn.transform(1 - sweepProg);
              intensity = gauss * (0.85 + 0.15 * edgeSoft);
            }
            final total = math.max(intensity, globalTail);

            final scale = 1 + (widget.peakScale - 1) * total;
            final color = Color.lerp(
                widget.color, Colors.white, widget.whiteMix * total)!;
            final glow = widget.maxGlow * total;
            final glowOpacity = (widget.glowOpacity * total).clamp(0.0, 1.0);

            nonSpace++;

            return Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: Text(
                ch,
                style: TextStyle(
                  color: color,
                  fontSize: widget.fontSize,
                  fontWeight: widget.fontWeight,
                  shadows: glow > 0.01
                      ? [
                          Shadow(
                            color: widget.color.withValues(alpha: glowOpacity),
                            blurRadius: glow,
                          )
                        ]
                      : null,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
