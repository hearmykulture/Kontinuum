import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieOnce extends StatefulWidget {
  const LottieOnce({
    super.key,
    required this.asset,
    required this.play,
    this.repeat = false,
    this.onCompleted,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final bool play;
  final bool repeat;
  final VoidCallback? onCompleted;
  final BoxFit fit;

  @override
  State<LottieOnce> createState() => _LottieOnceState();
}

class _LottieOnceState extends State<LottieOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void didUpdateWidget(covariant LottieOnce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) {
      _controller
        ..stop()
        ..reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Lottie.asset(
        widget.asset,
        controller: _controller,
        fit: widget.fit,
        repeat: widget.repeat,
        onLoaded: (composition) {
          _controller
            ..duration = composition.duration
            ..addStatusListener((s) {
              if (s == AnimationStatus.completed) widget.onCompleted?.call();
            });
          if (widget.play && !_controller.isAnimating) {
            _controller.forward(from: 0);
          }
        },
      ),
    );
  }
}
