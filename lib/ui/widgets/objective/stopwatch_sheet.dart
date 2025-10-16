import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Adjust this import path to wherever ObjectiveTokens is defined in your app.
import 'package:kontinuum/ui/widgets/objective/objective_tokens.dart';

class StopwatchSheet extends StatefulWidget {
  const StopwatchSheet({
    super.key,
    required this.onLogMinutes,
    required this.onMarkComplete,
    this.initialSeconds = 0,
    this.targetMinutes = 0,
    this.title, // optional objective title (OG showed it)
  });

  /// Called when the user taps "Log X mins".
  final void Function(int minutes) onLogMinutes;

  /// Called when the user taps "Mark complete".
  final VoidCallback onMarkComplete;

  /// Optional starting point for the stopwatch (in seconds).
  final int initialSeconds;

  /// Optional target for display in the log button, e.g. “(target 25m)”.
  final int targetMinutes;

  /// Optional title to display at the top (matches OG).
  final String? title;

  @override
  State<StopwatchSheet> createState() => _StopwatchSheetState();
}

class _StopwatchSheetState extends State<StopwatchSheet> {
  Timer? _timer;
  bool _running = false;
  int _elapsedSec = 0;

  @override
  void initState() {
    super.initState();
    _elapsedSec = widget.initialSeconds.clamp(0, 1 << 30);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick(Timer _) {
    if (!mounted) return;
    setState(() => _elapsedSec += 1);
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
      setState(() => _running = true);
    }
  }

  void _reset() {
    HapticFeedback.heavyImpact(); // OG used heavy impact on reset
    _timer?.cancel();
    setState(() {
      _running = false;
      _elapsedSec = 0;
    });
  }

  // OG mm:ss formatting
  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    // OG minute rounding: at least 1 when > 0 seconds elapsed
    final rawMinutes = (_elapsedSec / 60).ceil();
    final minutes = _elapsedSec > 0 ? (rawMinutes == 0 ? 1 : rawMinutes) : 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar (as in OG)
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Optional title (OG showed objective title here)
          if (widget.title != null) ...[
            Text(
              widget.title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: ObjectiveTokens.kSheetTitleSize,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
          ],

          Text(
            _running ? "Tap to pause" : "Tap to start stopwatch",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: ObjectiveTokens.kMicroSize,
            ),
          ),
          const SizedBox(height: 16),

          // Big timer — tappable for start/pause to match the hint text.
          GestureDetector(
            onTap: _toggle,
            child: Text(
              _fmt(_elapsedSec),
              semanticsLabel: 'Elapsed time ${_fmt(_elapsedSec)}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _toggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _running
                      ? Colors.redAccent
                      : Colors.greenAccent,
                  foregroundColor: Colors.black,
                ),
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                label: Text(_running ? 'Pause' : 'Start'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _elapsedSec > 0 ? _reset : null,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  foregroundColor: Colors.white70,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: minutes > 0
                      ? () {
                          HapticFeedback.mediumImpact();
                          widget.onLogMinutes(minutes);
                          Navigator.of(context).pop();
                        }
                      : null,
                  icon: const Icon(Icons.save),
                  label: Text(
                    'Log $minutes min${minutes == 1 ? "" : "s"}'
                    '${widget.targetMinutes > 0 ? " (target ${widget.targetMinutes}m)" : ""}',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onMarkComplete(); // parent will show overlay + notify
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Mark complete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.greenAccent,
                  side: const BorderSide(color: Colors.greenAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
