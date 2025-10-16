// lib/ui/widgets/objective/complete_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ripple_painter.dart';
import 'objective_tokens.dart';

class CompleteButton extends StatefulWidget {
  const CompleteButton({
    Key? key,
    required this.isCompleted,
    required this.onToggle,
  }) : super(key: key);

  final bool isCompleted;
  final VoidCallback onToggle;

  @override
  State<CompleteButton> createState() => _CompleteButtonState();
}

class _CompleteButtonState extends State<CompleteButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.0,
      upperBound: 0.10,
    );
    _ring =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _ring.value = 0;
        });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _ring.dispose();
    super.dispose();
  }

  void _onPressed() {
    final willComplete = !widget.isCompleted;
    if (willComplete) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    SystemSound.play(SystemSoundType.click);

    _pulse
      ..forward(from: 0)
      ..reverse();
    _ring.forward(from: 0);

    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.isCompleted
        ? Icons.check_circle
        : Icons.radio_button_unchecked;
    final color = widget.isCompleted ? Colors.greenAccent : Colors.white70;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _ring]),
      builder: (_, __) {
        final scale = 1 + _pulse.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: SizedBox(
                width: ObjectiveTokens.kCheckSize,
                height: ObjectiveTokens.kCheckSize,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(),
                  tooltip: widget.isCompleted
                      ? 'Mark incomplete'
                      : 'Mark complete',
                  onPressed: _onPressed,
                  icon: Icon(
                    icon,
                    color: color,
                    size: ObjectiveTokens.kCheckSize,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: SizedBox(
                width: ObjectiveTokens.kCheckSize,
                height: ObjectiveTokens.kCheckSize,
                child: CustomPaint(
                  painter: RipplePainter(
                    progress: _ring.value,
                    rrectRadius: ObjectiveTokens.kCheckSize / 2,
                    color: widget.isCompleted
                        ? Colors.white
                        : Colors.greenAccent,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
