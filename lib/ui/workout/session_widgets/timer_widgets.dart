import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kontinuum/ui/workout/session_widgets/workout_elapsed_tracker.dart';

const Color _kAccentGreen = Color(0xFF21D07A);
const int _kDefaultRestSeconds = 60;
const String _kLogSetHeroTag = 'logSetHeroBubble';

/// LARGE CIRCULAR STOPWATCH / REST WIDGET
class SetTimerCard extends StatefulWidget {
  const SetTimerCard({
    required this.ringSize,
    required this.onCountingChanged,
    required this.onLogTap,
    this.highlightComplete = false,
    this.countdownSeconds,
    super.key,
  });

  final double ringSize;
  final ValueChanged<bool> onCountingChanged;
  final VoidCallback onLogTap;
  final int? countdownSeconds;

  /// When true (after the final rest of the last target set), the whole ring
  /// turns green to match the Complete pill.
  final bool highlightComplete;

  @override
  State<SetTimerCard> createState() => SetTimerCardState();
}

enum _TimerMode { stopwatch, rest }

class SetTimerCardState extends State<SetTimerCard>
    with TickerProviderStateMixin {
  // Stopwatch
  Duration _elapsed = Duration.zero;
  Duration _workElapsed = Duration.zero;
  Duration _workRemaining = Duration.zero;
  Duration _sessionElapsed = Duration.zero;
  bool _running = false;

  // Rest
  _TimerMode _mode = _TimerMode.stopwatch;
  int _restTotal = _kDefaultRestSeconds;
  int _restRemaining = _kDefaultRestSeconds;
  bool _restPaused = false;
  int? get _countdownTotal {
    final seconds = widget.countdownSeconds;
    if (seconds == null || seconds <= 0) return null;
    return seconds;
  }

  bool get _useCountdown => _countdownTotal != null;

  Timer? _ticker;

  // Layout animation: when Log button hides (rest), digits slide toward center
  late final AnimationController _layoutCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final CurvedAnimation _layoutCurve =
      CurvedAnimation(parent: _layoutCtrl, curve: Curves.easeOutCubic);

  // Completion animation: green fill-up when workout is complete
  late final AnimationController _completeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _completeSweep = Tween<double>(
    begin: 0.0,
    end: 2 * math.pi,
  ).animate(CurvedAnimation(
    parent: _completeCtrl,
    curve: Curves.easeInOutCubic,
  ));

  // Public API ---------------------------------------------------------------
  bool get isStopwatchRunning => _running && _mode == _TimerMode.stopwatch;

  // Session persistence getters
  Duration get elapsed => _useCountdown ? _workElapsed : _elapsed;
  bool get running => _running;
  String get timerMode => _mode == _TimerMode.rest ? 'rest' : 'stopwatch';
  int get restTotal => _restTotal;
  int get restRemaining => _restRemaining;
  bool get restPaused => _restPaused;

  // Session persistence restore methods
  void restoreState({
    required int elapsedSeconds,
    required bool wasRunning,
    required String mode,
    required int restTotalSec,
    required int restRemainingSec,
    required bool restWasPaused,
  }) {
    _ticker?.cancel();
    final nextMode = mode == 'rest' ? _TimerMode.rest : _TimerMode.stopwatch;
    final countdownTotal = _countdownTotal;
    final Duration restoredElapsed = Duration(seconds: elapsedSeconds);
    final Duration trackedElapsed =
        WorkoutElapsedTracker.instance.value.elapsed;
    final Duration sessionElapsed = (trackedElapsed > restoredElapsed)
        ? trackedElapsed
        : restoredElapsed;
    setState(() {
      _elapsed = restoredElapsed;
      _mode = nextMode;
      if (countdownTotal != null) {
        final int clamped = elapsedSeconds.clamp(0, countdownTotal);
        _workElapsed = Duration(seconds: clamped);
        _workRemaining =
            Duration(seconds: math.max(0, countdownTotal - clamped));
      } else {
        _workElapsed = Duration(seconds: elapsedSeconds);
        _workRemaining = Duration.zero;
      }
      _restTotal = restTotalSec;
      _restRemaining = restRemainingSec;
      _restPaused = restWasPaused;
      _running = wasRunning;
      _sessionElapsed = sessionElapsed;
    });

    if (_mode == _TimerMode.rest) {
      _layoutCtrl.forward();
      if (!_restPaused) {
        _startTicker();
      }
    } else {
      _layoutCtrl.reverse();
      if (wasRunning) {
        _startTicker();
      }
    }
    _notifyCounting();
    _publishElapsed();
  }

  void toggleStartPause() {
    if (_mode == _TimerMode.rest) {
      _setRestRunning(_restPaused);
    } else {
      _setStopwatchRunning(!_running);
    }
  }

  void rewind15() {
    setState(() {
      if (_mode == _TimerMode.stopwatch) {
        if (_useCountdown) {
          final int total = _countdownTotal!;
          final int work = math.max(0, _workElapsed.inSeconds - 15);
          _workElapsed = Duration(seconds: work);
          _workRemaining = Duration(seconds: math.max(0, total - work));
          _elapsed = _workElapsed;
        } else {
          final s = math.max(0, _elapsed.inSeconds - 15);
          _elapsed = Duration(seconds: s);
          _workElapsed = _elapsed;
        }
      } else {
        _restRemaining = math.max(0, _restRemaining - 15);
      }
    });
    _publishElapsed();
  }

  void forward15() {
    setState(() {
      if (_mode == _TimerMode.stopwatch) {
        if (_useCountdown) {
          final int total = _countdownTotal!;
          final int work =
              math.min(total, _workElapsed.inSeconds + 15);
          _workElapsed = Duration(seconds: work);
          _workRemaining = Duration(seconds: math.max(0, total - work));
          _elapsed = _workElapsed;
        } else {
          _elapsed = Duration(seconds: _elapsed.inSeconds + 15);
          _workElapsed = _elapsed;
        }
      } else {
        _restRemaining = math.min(_restTotal, _restRemaining + 15);
      }
    });
    _publishElapsed();
  }

  void pauseStopwatchPublic() => _setStopwatchRunning(false);
  void resumeStopwatchPublic() => _setStopwatchRunning(true);

  void beginRestPublic([int? seconds]) {
    _ticker?.cancel();
    final int fallbackRest =
        _restTotal > 0 ? _restTotal : _kDefaultRestSeconds;
    final int nextRest =
        (seconds ?? fallbackRest).clamp(0, 3600);
    setState(() {
      _mode = _TimerMode.rest;
      _restTotal = nextRest;
      _restRemaining = _restTotal;
      _restPaused = false;
      _running = true;
      _workElapsed = Duration.zero;
      _workRemaining = Duration(seconds: _countdownTotal ?? 0);
      if (_useCountdown) {
        _elapsed = Duration.zero;
      }
    });
    _layoutCtrl.forward(); // digits → center-ish
    _startTicker();
    _notifyCounting();
  }

  /// Instantly finish the current rest period.
  void skipRestPublic() {
    if (_mode == _TimerMode.rest) {
      _endRest();
    }
  }

  void cancelRestAndResetStopwatch() {
    _ticker?.cancel();
    setState(() {
      _mode = _TimerMode.stopwatch;
      _restPaused = false;
      _running = false;
      _elapsed = Duration.zero;
      _workElapsed = Duration.zero;
      _workRemaining = Duration(seconds: _countdownTotal ?? 0);
    });
    _layoutCtrl.reverse(); // digits lift (space for Log button)
    _notifyCounting();
    _publishElapsed();
  }

  // Lifecycle ---------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _layoutCtrl.value = 0.0;
    _workRemaining = Duration(seconds: _countdownTotal ?? 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyCounting();
      _publishElapsed();
    });
    if (widget.highlightComplete) {
      _completeCtrl.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant SetTimerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger green fill-up animation when workout completes
    if (widget.highlightComplete && !oldWidget.highlightComplete) {
      _completeCtrl.forward(from: 0);
    } else if (!widget.highlightComplete && oldWidget.highlightComplete) {
      _completeCtrl.reset();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _layoutCtrl.dispose();
    _completeCtrl.dispose();
    super.dispose();
  }

  // Internals ---------------------------------------------------------------
  void _notifyCounting() => widget.onCountingChanged(_isCounting);

  bool get _isCounting =>
      (_mode == _TimerMode.stopwatch && _running) ||
      (_mode == _TimerMode.rest && !_restPaused);

  void _setStopwatchRunning(bool v) {
    if (_mode != _TimerMode.stopwatch) {
      setState(() => _mode = _TimerMode.stopwatch);
      _layoutCtrl.reverse();
    }
    _running = v;
    if (v) {
      _startTicker();
    } else {
      _ticker?.cancel();
    }
    setState(() {});
    _notifyCounting();
    _publishElapsed();
  }

  void _setRestRunning(bool resume) {
    if (_mode != _TimerMode.rest) {
      setState(() => _mode = _TimerMode.rest);
      _layoutCtrl.forward();
    }
    _restPaused = !resume;
    if (resume) {
      _startTicker();
    } else {
      _ticker?.cancel();
    }
    setState(() {});
    _notifyCounting();
    _publishElapsed();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    if (!mounted) return;
    if (!_isCounting) return;
    _sessionElapsed += const Duration(seconds: 1);
    if (_mode == _TimerMode.stopwatch) {
      if (_useCountdown) {
        final int total = _countdownTotal!;
        if (_workRemaining.inSeconds <= 1) {
          setState(() {
            final nextElapsed = math.min(total, _workElapsed.inSeconds + 1);
            _workElapsed = Duration(seconds: nextElapsed);
            _workRemaining = Duration.zero;
            _elapsed = _workElapsed;
            _running = false;
          });
          _ticker?.cancel();
          _notifyCounting();
        } else {
          setState(() {
            _workElapsed = Duration(seconds: _workElapsed.inSeconds + 1);
            _workRemaining =
                Duration(seconds: math.max(0, _workRemaining.inSeconds - 1));
            _elapsed = _workElapsed;
          });
        }
      } else {
        setState(() {
          _elapsed = Duration(seconds: _elapsed.inSeconds + 1);
          _workElapsed = Duration(seconds: _workElapsed.inSeconds + 1);
        });
      }
      _publishElapsed();
    } else {
      if (_restRemaining <= 1) {
        _endRest();
      } else {
        setState(() => _restRemaining -= 1);
        _publishElapsed();
      }
    }
  }

  void _endRest() {
    _ticker?.cancel();
    setState(() {
      _restRemaining = 0;
      _mode = _TimerMode.stopwatch;
      _running = false;
      _restPaused = false;
      _workElapsed = Duration.zero;
      _workRemaining = Duration(seconds: _countdownTotal ?? 0);
      if (_useCountdown) {
        _elapsed = Duration.zero;
      }
    });
    _layoutCtrl.reverse();
    _notifyCounting();
    _publishElapsed();
  }

  String _mmss(Duration d) {
    final m = (d.inSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) {
      final hh = h.toString().padLeft(2, '0');
      final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
      return '$hh:$mm:$s';
    }
    return '$m:$s';
  }

  String _mmssRest(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static const int _stopwatchCycleSeconds = 60;

  double _stopwatchSweep() {
    if (_mode != _TimerMode.stopwatch) return 0;
    if (_useCountdown) {
      final int total = _countdownTotal!;
      if (total <= 0) return 0;
      final double fraction =
          (_workElapsed.inSeconds / total).clamp(0, 1).toDouble();
      return fraction * 2 * math.pi;
    }
    if (_stopwatchCycleSeconds <= 0) return 0;
    final int totalSeconds = _workElapsed.inSeconds;
    if (totalSeconds == 0) return 0;
    final int remainder = totalSeconds % _stopwatchCycleSeconds;
    final double fraction =
        (remainder == 0 && totalSeconds > 0)
            ? 1.0
            : remainder / _stopwatchCycleSeconds;
    return fraction * 2 * math.pi;
  }

  double _restSweep() {
    if (_mode != _TimerMode.rest || _restTotal == 0) return 0;
    final done = (_restTotal - _restRemaining).clamp(0, _restTotal);
    return done / _restTotal * 2 * math.pi;
  }

  @override
  Widget build(BuildContext context) {
    const Color ringBlue = Color(0xFF8EDCF0);

    final bool danger =
        _mode == _TimerMode.rest && !_restPaused && _restRemaining <= 5;
    final double size = widget.ringSize;

    final bool completed = widget.highlightComplete;

    // ▶ Thinner ring
    final double stroke = (size * 0.065).clamp(8.0, 16.0);

    // Protect digits from clipping against the ring.
    final double safeInnerWidth = math.max(0, size - stroke * 2 - 18);

    // Digits alignment animates between slightly-up and near-center.
    final Alignment digitsAlign = AlignmentTween(
      begin: const Alignment(0, -0.10),
      end: const Alignment(0, -0.02),
    ).evaluate(_layoutCurve);

    return AnimatedBuilder(
      animation: _completeCtrl,
      builder: (context, child) {
        // Animate green fill-up when complete
        final bool inRest = _mode == _TimerMode.rest;
        final double sweep = completed
            ? _completeSweep.value
            : (inRest ? _restSweep() : _stopwatchSweep());
        final Color trackColor = completed
            ? _kAccentGreen.withValues(alpha: 0.26)
            : Colors.black.withValues(alpha: 0.10);
        final Color ringColor =
            completed ? _kAccentGreen : (danger ? const Color(0xFFD83A3A) : ringBlue);

        return _buildTimerWidget(
          size: size,
          stroke: stroke,
          safeInnerWidth: safeInnerWidth,
          digitsAlign: digitsAlign,
          sweep: sweep,
          trackColor: trackColor,
          ringColor: ringColor,
          completed: completed,
        );
      },
    );
  }

  Widget _buildTimerWidget({
    required double size,
    required double stroke,
    required double safeInnerWidth,
    required Alignment digitsAlign,
    required double sweep,
    required Color trackColor,
    required Color ringColor,
    required bool completed,
  }) {
    return SizedBox(
      width: size,
      height: size, // fixed square
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring
          RepaintBoundary(
            child: CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                sweepRadians: sweep,
                trackColor: trackColor,
                ringColor: ringColor,
                stroke: stroke,
                showHeadDot: !completed,
              ),
            ),
          ),

          // Big digits (make 100% non-interactive so button always wins taps)
          IgnorePointer(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: digitsAlign,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: safeInnerWidth),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _mode == _TimerMode.rest
                        ? _mmssRest(_restRemaining)
                        : (_useCountdown
                            ? _mmss(_workRemaining)
                            : _mmss(_workElapsed)),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: 0.5,
                      color: (_mode == _TimerMode.rest && !_restPaused && _restRemaining <= 5)
                          ? const Color(0xFFD83A3A)
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // In-ring “Log set” button (work stopwatch mode)
          _LogButton(
            visible: _mode == _TimerMode.stopwatch,
            onTap: widget.onLogTap,
            yAlign: 0.66,
          ),

          // In-ring "Skip rest" button (rest mode)
          _SkipRestButton(
            visible: _mode == _TimerMode.rest,
            onTap: skipRestPublic,
            yAlign: 0.66,
          ),
        ],
      ),
    );
  }

  void _publishElapsed() {
    WorkoutElapsedTracker.instance.update(_sessionElapsed, _isCounting);
  }
}

/// In-ring "Log set" button with Hero
class _LogButton extends StatelessWidget {
  const _LogButton({
    required this.visible,
    required this.onTap,
    this.yAlign = 0.56,
  });

  final bool visible;
  final VoidCallback onTap;
  final double yAlign;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(0, yAlign),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 0.10),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          opacity: visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Hero(
                tag: _kLogSetHeroTag,
                flightShuttleBuilder: (_, __, dir, from, to) =>
                    dir == HeroFlightDirection.push ? to.widget : from.widget,
                child: PillButton(
                  label: 'Log set',
                  emphasis: true,
                  onTap: onTap,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// In-ring “Skip rest” button (no Hero)
class _SkipRestButton extends StatelessWidget {
  const _SkipRestButton({
    required this.visible,
    required this.onTap,
    this.yAlign = 0.70,
  });

  final bool visible;
  final VoidCallback onTap;
  final double yAlign;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(0, yAlign),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 0.10),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          opacity: visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: PillButton(
                label: 'Skip rest',
                onTap: onTap,
                emphasis: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ring painter
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.sweepRadians,
    required this.trackColor,
    required this.ringColor,
    required this.stroke,
    this.showHeadDot = true,
  });

  final double sweepRadians;
  final Color trackColor;
  final Color ringColor;
  final double stroke;

  /// Whether to draw the moving "head" dot at the end of the arc.
  /// We hide this when the ring is fully complete/green.
  final bool showHeadDot;

  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (sweepRadians > 0) {
      final ring = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      final start = -math.pi / 2; // top
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweepRadians,
        false,
        ring,
      );

      if (showHeadDot) {
        // leading dot
        final ang = start + sweepRadians;
        final p = Offset(center.dx + radius * math.cos(ang),
            center.dy + radius * math.sin(ang));
        final head = Paint()..color = ringColor;
        canvas.drawCircle(p, stroke * 0.45, head);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.sweepRadians != sweepRadians ||
      old.trackColor != trackColor ||
      old.ringColor != ringColor ||
      old.stroke != stroke ||
      old.showHeadDot != showHeadDot;
}

/// Reusable pill button
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.subtle = false,
    this.emphasis = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool subtle;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final Color fg = emphasis
        ? Colors.white
        : (subtle ? Colors.black.withValues(alpha: 0.7) : Colors.black87);
    final Color bg = emphasis
        ? _kAccentGreen
        : Colors.black.withValues(alpha: subtle ? 0.04 : 0.08);
    final Color bd =
        Colors.black.withValues(alpha: subtle ? 0.10 : (emphasis ? 0.00 : 0.12));

    const radius = BorderRadius.all(Radius.circular(12));

    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: bg,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: bd),
              borderRadius: radius,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
