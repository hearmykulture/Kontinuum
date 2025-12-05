import 'package:flutter/material.dart';

/// Centralized tokens (no circular import with the screen).
class BudgetTheme {
  static const Color bg = Color(0xFF0B2B26);
  static const Color mint = Color(0xFFDAF1DE);
  static const Color mintDim = Color(0xCCDAF1DE);
  static const Color text = Colors.white;
  static const Color textMuted = Colors.white70;
  static const Color accent = Color(0xFF8EB69B);
  static const Color unallocatedGray = Color(0xFF9AA0A6);

  static Color dividerOnCard(BuildContext _) => Colors.white.withValues(alpha: 0.08);
}
