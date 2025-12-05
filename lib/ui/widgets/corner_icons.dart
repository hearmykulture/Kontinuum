import 'package:flutter/material.dart';

/// Reusable widget for top corner icons (delete on left, close on right)
class CornerIcons extends StatelessWidget {
  const CornerIcons({
    super.key,
    this.top = 0,
    this.leftIcon,
    this.onLeftPressed,
    this.rightIcon,
    this.onRightPressed,
    this.leftTooltip = 'Delete',
    this.rightTooltip = 'Close',
  });

  /// Distance from the top (can be negative)
  final double top;

  /// Icon data for the left button
  final IconData? leftIcon;

  /// Callback for left button press
  final VoidCallback? onLeftPressed;

  /// Icon data for the right button
  final IconData? rightIcon;

  /// Callback for right button press
  final VoidCallback? onRightPressed;

  /// Tooltip for left button
  final String leftTooltip;

  /// Tooltip for right button
  final String rightTooltip;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left button (delete/trash)
          if (leftIcon != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: leftTooltip,
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                ),
                icon: Icon(leftIcon, size: 22),
                onPressed: onLeftPressed,
              ),
            )
          else
            const Spacer(),
          // Right button (close/X)
          if (rightIcon != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: rightTooltip,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(8),
                ),
                icon: Icon(rightIcon, size: 20),
                onPressed: onRightPressed,
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}
