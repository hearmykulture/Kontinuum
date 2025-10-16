import 'package:flutter/widgets.dart';

/// Clips the left-most part of the lane so rail/badges never peek through.
class LaneClipper extends CustomClipper<Rect> {
  const LaneClipper(this.leftInset);
  final double leftInset;

  @override
  Rect getClip(Size size) {
    final li = leftInset.clamp(0.0, size.width);
    final w = (size.width - li).clamp(0.0, size.width);
    return Rect.fromLTWH(li, 0, w, size.height);
  }

  @override
  bool shouldReclip(LaneClipper oldClipper) =>
      oldClipper.leftInset != leftInset;
}
