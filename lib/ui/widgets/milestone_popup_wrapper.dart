import 'package:flutter/material.dart';

class MilestonePopupWrapper extends StatefulWidget {
  final Widget child;
  final Rect pillRect;

  const MilestonePopupWrapper({
    super.key,
    required this.child,
    required this.pillRect,
  });

  @override
  State<MilestonePopupWrapper> createState() => _MilestonePopupWrapperState();
}

class _MilestonePopupWrapperState extends State<MilestonePopupWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnim;
  late Animation<double> _heightAnim;
  late Animation<double> _leftAnim;
  late Animation<double> _topAnim;

  bool _ready = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Delay to ensure MediaQuery is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenSize = MediaQuery.of(context).size;

      // Reduced width for padding, taller height
      final popupWidth = screenSize.width * 0.86;
      final popupHeight = screenSize.height * 0.82;

      final targetLeft = (screenSize.width - popupWidth) / 2;
      final targetTop = screenSize.height - 85 - popupHeight;

      final pillWidth = widget.pillRect.width.clamp(0.0, screenSize.width);
      final pillHeight = widget.pillRect.height.clamp(0.0, screenSize.height);

      final safeLeft = widget.pillRect.left.clamp(
        0.0,
        screenSize.width - pillWidth,
      );
      final safeTop = widget.pillRect.top.clamp(
        0.0,
        screenSize.height - pillHeight,
      );

      _widthAnim = Tween<double>(begin: pillWidth, end: popupWidth).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );

      _heightAnim = Tween<double>(begin: pillHeight, end: popupHeight).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );

      _leftAnim = Tween<double>(begin: safeLeft, end: targetLeft).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );

      _topAnim = Tween<double>(begin: safeTop, end: targetTop).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );

      setState(() => _ready = true);
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) => Navigator.of(context).pop());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Stack(
          children: [
            if (_ready)
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  return Positioned(
                    left: _leftAnim.value,
                    top: _topAnim.value,
                    width: _widthAnim.value,
                    height: _heightAnim.value,
                    child: SafeArea(
                      child: Material(
                        borderRadius: BorderRadius.circular(24),
                        color: const Color(0xFF1A1A1A),
                        child: GestureDetector(
                          onTap: () {}, // absorb inner taps
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
