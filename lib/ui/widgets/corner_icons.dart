import 'package:flutter/material.dart';

/// Reusable widget for top corner icons (delete on left, close on right)
class CornerIcons extends StatelessWidget {
  const CornerIcons({
    super.key,
    this.top = 0,
    this.horizontalInset = 0,
    this.leftIcon,
    this.onLeftPressed,
    this.leftIconSize,
    this.leftIconColor,
    this.rightIcon,
    this.onRightPressed,
    this.rightIconSize,
    this.rightIconColor,
    this.leftTooltip = 'Delete',
    this.rightTooltip = 'Close',
  });

  /// Distance from the top (can be negative)
  final double top;

  /// Adjust how far the row stretches horizontally (negative = wider).
  final double horizontalInset;

  /// Icon data for the left button
  final IconData? leftIcon;

  /// Callback for left button press
  final VoidCallback? onLeftPressed;

  /// Optional left icon size override
  final double? leftIconSize;

  /// Optional left icon color override
  final Color? leftIconColor;

  /// Icon data for the right button
  final IconData? rightIcon;

  /// Callback for right button press
  final VoidCallback? onRightPressed;

  /// Optional right icon size override
  final double? rightIconSize;

  /// Optional right icon color override
  final Color? rightIconColor;

  /// Tooltip for left button
  final String leftTooltip;

  /// Tooltip for right button
  final String rightTooltip;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: horizontalInset,
      right: horizontalInset,
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
                  foregroundColor:
                      leftIconColor ?? const Color(0xFFFF3B30),
                  padding: const EdgeInsets.all(8),
                ),
                icon: Icon(leftIcon, size: leftIconSize ?? 22),
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
                  foregroundColor: rightIconColor ?? Colors.white,
                  padding: const EdgeInsets.all(8),
                ),
                icon: Icon(rightIcon, size: rightIconSize ?? 20),
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
