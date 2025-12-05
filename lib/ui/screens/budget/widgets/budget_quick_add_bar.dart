// lib/ui/screens/budget/widgets/budget_quick_add_bar.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable triple FAB used by the budget screen:
/// center "+" plus two side pills (left/right) with drag-to-trigger.
///
/// It manages its own animation + full-screen overlay via OverlayEntry.
/// The parent just needs to pass the accent color and the two callbacks.
class BudgetQuickAddBar extends StatefulWidget {
  const BudgetQuickAddBar({
    super.key,
    required this.accent,
    required this.onTapLeft,
    required this.onTapRight,
    this.onTapSingle,
    this.singleAction = false,
    this.fabLift = 44.0,
    this.leftIcon = Icons.alarm_add_rounded,
    this.rightIcon = Icons.event_available_rounded,
  });

  /// Accent color used for borders / active pills.
  final Color accent;

  /// Called when the LEFT pill is activated (tap or drag).
  final VoidCallback onTapLeft;

  /// Called when the RIGHT pill is activated (tap or drag).
  final VoidCallback onTapRight;

  /// Optional single-action mode (no overlay) uses this callback.
  final VoidCallback? onTapSingle;

  /// If true, behaves like a normal FAB (no split overlay).
  final bool singleAction;

  /// Vertical lift used to keep the side pills visually aligned with
  /// a lifted FAB location.
  ///
  /// For a normal centerFloat FAB, pass 0 (or rely on the fallback).
  /// For a lifted FAB (like the calendar) pass the same lift.
  final double fabLift;

  final IconData leftIcon;
  final IconData rightIcon;

  @override
  State<BudgetQuickAddBar> createState() => _BudgetQuickAddBarState();
}

class _BudgetQuickAddBarState extends State<BudgetQuickAddBar>
    with SingleTickerProviderStateMixin {
  // --- Layout constants (copied from calendar_fullscreen_page) ---
  static const double _fabSize = 64;
  static const double _slotSize = 56;
  static const double _slotHit = 92;
  static const double _slotSpacing = 84;
  static const double _dragThreshold = 44;
  static const double _showAtT = 0.22;

  // --- Animation ---
  late final AnimationController _fabCtrl;
  late final Animation<double> _fabEase;

  OverlayEntry? _overlayEntry;

  bool _dragActive = false;
  int _hoverDir = 0; // -1 = left, 1 = right
  double _dragAccumX = 0.0;
  bool _pressLeft = false;
  bool _pressRight = false;

  /// FAB bounds in overlay coordinates, captured when opening.
  Rect? _fabRect;

  bool get _fabOpen => _fabCtrl.value > 0.01;
  bool get _simple => widget.singleAction;

  Color _withAlpha(Color c, double a) => c.withValues(alpha: a.clamp(0.0, 1.0));

  @override
  void initState() {
    super.initState();
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _fabEase = CurvedAnimation(
      parent: _fabCtrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    // Rebuild overlay as the animation ticks.
    _fabEase.addListener(() {
      _overlayEntry?.markNeedsBuild();
    });

    // When fully collapsed and not dragging, remove the overlay.
    _fabCtrl.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !_dragActive) {
        _removeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _fabCtrl.dispose();
    super.dispose();
  }

  void _ensureOverlay() {
    if (_simple) return;
    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    // Capture FAB rect in overlay coordinates so we can vertically align
    // the side pills with the center of the FAB.
    final RenderBox? fabBox = context.findRenderObject() as RenderBox?;
    final RenderBox? overlayBox =
        overlay.context.findRenderObject() as RenderBox?;

    if (fabBox != null && overlayBox != null) {
      final Offset topLeft =
          fabBox.localToGlobal(Offset.zero, ancestor: overlayBox);
      _fabRect = topLeft & fabBox.size;
    } else {
      _fabRect = null;
    }

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _buildOverlay(ctx),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    if (_simple) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _fabRect = null;
  }

  void _toggleFab() {
    if (_simple) {
      widget.onTapSingle?.call();
      return;
    }
    if (_fabOpen) {
      _fabCtrl.reverse();
    } else {
      _ensureOverlay();
      _fabCtrl.forward();
    }
    setState(() {});
  }

  void _handlePanStart(DragStartDetails _) {
    if (_simple) return;
    _dragActive = true;
    _dragAccumX = 0.0;
    _hoverDir = 0;
    _ensureOverlay();
    _fabCtrl.forward();
    setState(() {});
  }

  void _handlePanUpdate(DragUpdateDetails d) {
    if (_simple) return;
    _dragAccumX += d.delta.dx;
    final int dir = (_dragAccumX >= _dragThreshold)
        ? 1
        : (_dragAccumX <= -_dragThreshold)
            ? -1
            : 0;

    if (dir != _hoverDir) {
      _hoverDir = dir;
      HapticFeedback.selectionClick();
      setState(() {});
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _closeInstant() {
    _dragActive = false;
    _hoverDir = 0;
    _pressLeft = false;
    _pressRight = false;
    _fabCtrl.stop();
    _fabCtrl.value = 0.0;
    _removeOverlay();
    setState(() {});
  }

  void _handlePanEnd([DragEndDetails? _]) {
    if (_simple) return;
    final int dir = _hoverDir;
    _dragActive = false;
    _hoverDir = 0;

    if (dir == -1) {
      // Dragged left → left action
      HapticFeedback.mediumImpact();
      _closeInstant();
      widget.onTapLeft();
    } else if (dir == 1) {
      // Dragged right → right action
      HapticFeedback.mediumImpact();
      _closeInstant();
      widget.onTapRight();
    } else {
      // No direction → just close if open.
      if (_fabOpen) {
        _fabCtrl.reverse();
      } else {
        _removeOverlay();
      }
    }

    _overlayEntry?.markNeedsBuild();
  }

  void _handleSlotTap(VoidCallback action) {
    if (_simple) return;
    HapticFeedback.mediumImpact();
    _closeInstant();
    action();
  }

  Widget _buildOverlay(BuildContext context) {
    if (_simple) return const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final pad = media.padding;
    final double screenHeight = media.size.height;

    return IgnorePointer(
      ignoring: !(_fabOpen || _dragActive),
      child: AnimatedBuilder(
        animation: _fabEase,
        builder: (context, _) {
          final double t = _fabEase.value;
          if (!(_fabOpen || _dragActive) && t == 0.0) {
            return const SizedBox.shrink();
          }

          final double leftDx = -_slotSpacing * t;
          final double rightDx = _slotSpacing * t;
          final double sideScale = 0.80 + 0.20 * _fabCtrl.value;
          final bool showSides = t >= _showAtT;

          final double menuH = _fabSize + 20;

          // Align the side pills' vertical CENTER with the FAB's center,
          // so they sit on the same level as the "+" / "X" button.
          double menuBottom;
          if (_fabRect != null) {
            final double fabCenterY = _fabRect!.top + _fabRect!.height / 2.0;
            final double centerOffsetFromBottom = screenHeight - fabCenterY;
            menuBottom = centerOffsetFromBottom - (menuH / 2.0);

            // Safety clamp so we don't dip under the bottom padding.
            final double minBottom = pad.bottom + 2;
            if (menuBottom < minBottom) {
              menuBottom = minBottom;
            }
          } else {
            // Fallback: padding-based alignment, slightly lower so they
            // don't ride too high above the FAB.
            menuBottom = 6 + pad.bottom + widget.fabLift;
          }

          BoxDecoration pill(bool active) => BoxDecoration(
                color: active
                    ? _withAlpha(widget.accent, 0.20)
                    : const Color(0x331C1F28),
                borderRadius: BorderRadius.circular(_slotSize / 2),
                border: Border.all(
                  color: active
                      ? _withAlpha(widget.accent, 0.85)
                      : const Color(0x66FFFFFF),
                  width: active ? 2 : 1,
                ),
                boxShadow: [
                  if (active)
                    const BoxShadow(
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: Offset(0, 6),
                      color: Color(0x55000000),
                    ),
                ],
              );

          Widget slotButton({
            required bool isLeft,
            required IconData icon,
            required VoidCallback onPressed,
            required bool hover,
            required double dx,
            required Alignment align,
          }) {
            final bool pressed = isLeft ? _pressLeft : _pressRight;
            final bool active = hover || pressed;

            return Transform.translate(
              offset: Offset(dx, 0),
              transformHitTests: true,
              child: Transform.scale(
                scale: sideScale * (active ? 1.10 : 1.0),
                alignment: align,
                transformHitTests: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    setState(() {
                      if (isLeft) {
                        _pressLeft = true;
                      } else {
                        _pressRight = true;
                      }
                    });
                    _overlayEntry?.markNeedsBuild();
                  },
                  onTapCancel: () {
                    setState(() {
                      if (isLeft) {
                        _pressLeft = false;
                      } else {
                        _pressRight = false;
                      }
                    });
                    _overlayEntry?.markNeedsBuild();
                  },
                  onTapUp: (_) {
                    setState(() {
                      if (isLeft) {
                        _pressLeft = false;
                      } else {
                        _pressRight = false;
                      }
                    });
                    _overlayEntry?.markNeedsBuild();
                    _handleSlotTap(onPressed);
                  },
                  child: SizedBox(
                    width: _slotHit,
                    height: _slotHit,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 110),
                        curve: Curves.easeOut,
                        height: _slotSize,
                        width: _slotSize,
                        decoration: pill(active),
                        alignment: Alignment.center,
                        child: Icon(icon, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              // Tap anywhere to close quick-add
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_fabOpen && !_dragActive) {
                      _fabCtrl.reverse();
                    }
                  },
                ),
              ),
              if (showSides)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: menuBottom,
                  child: Center(
                    child: SizedBox(
                      width: _slotSpacing * 2 + _fabSize + 40,
                      height: menuH,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          slotButton(
                            isLeft: true,
                            icon: widget.leftIcon,
                            onPressed: widget.onTapLeft,
                            hover: _hoverDir == -1,
                            dx: leftDx,
                            align: Alignment.centerRight,
                          ),
                          slotButton(
                            isLeft: false,
                            icon: widget.rightIcon,
                            onPressed: widget.onTapRight,
                            hover: _hoverDir == 1,
                            dx: rightDx,
                            align: Alignment.centerLeft,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleFab,
      onPanStart: _simple ? null : _handlePanStart,
      onPanUpdate: _simple ? null : _handlePanUpdate,
      onPanEnd: _simple ? null : _handlePanEnd,
      child: Container(
        height: _fabSize,
        width: _fabSize,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2F3A),
          borderRadius: BorderRadius.circular(_fabSize / 2),
          boxShadow: const [
            BoxShadow(
              blurRadius: 20,
              spreadRadius: 2,
              offset: Offset(0, 8),
              color: Color(0x66000000),
            ),
          ],
          border: Border.all(
            color: _withAlpha(widget.accent, _fabOpen ? 0.7 : 0.3),
            width: _fabOpen ? 2 : 1,
          ),
        ),
        child: AnimatedBuilder(
          animation: _fabEase,
          builder: (_, __) {
            final rot = _simple ? 0.0 : (math.pi / 4) * _fabCtrl.value;
            return Transform.rotate(
              angle: rot,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            );
          },
        ),
      ),
    );
  }
}
