import 'package:flutter/foundation.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class WorkoutElapsedState {
  final Duration elapsed;
  final bool running;
  final DateTime? anchor;
  const WorkoutElapsedState({
    required this.elapsed,
    required this.running,
    required this.anchor,
  });
}

class WorkoutElapsedTracker extends ValueNotifier<WorkoutElapsedState> {
  WorkoutElapsedTracker._()
      : _anchor = null,
        super(const WorkoutElapsedState(
          elapsed: Duration.zero,
          running: false,
          anchor: null,
        ));

  static final WorkoutElapsedTracker instance = WorkoutElapsedTracker._();

  DateTime? _anchor;

  void update(Duration elapsed, bool running) {
    if (elapsed == Duration.zero && !running) {
      _anchor = null;
    } else if (_anchor == null && elapsed > Duration.zero) {
      _anchor = AppClock.now().subtract(elapsed);
    }
    final current = value;
    if (current.elapsed == elapsed &&
        current.running == running &&
        current.anchor == _anchor) {
      return;
    }
    value = WorkoutElapsedState(
      elapsed: elapsed,
      running: running,
      anchor: _anchor,
    );
  }

  void reset() {
    _anchor = null;
    value = const WorkoutElapsedState(
      elapsed: Duration.zero,
      running: false,
      anchor: null,
    );
  }
}
