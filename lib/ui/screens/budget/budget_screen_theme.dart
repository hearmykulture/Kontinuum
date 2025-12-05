import 'package:flutter/material.dart';

/// Shared colors for the Budget screen so sub-widgets don't need to depend
/// directly on BudgetScreenV2 (avoids circular imports).
class BudgetScreenTheme {
  /// Primary background color for the Budget screen Scaffold and page-level containers.
  /// Used for the main page background in both PageView (swipe) and full-screen (push) navigation.
  /// Applied to: Scaffold backgroundColor, Container wrapper in PageView, YearProgressBar background
  static const Color budgetGreen = Color(0xFF051F20); // page bg

  /// Secondary color for expandable cards and overlay sections.
  /// Used for budget cards, carousel tiles, and the expanded creation overlay.
  static const Color buttonGreen = Color(0xFF0B2B26); // cards & overlay

  /// Accent color for buttons, icons, and interactive elements.
  /// High contrast against the green backgrounds for clear visibility.
  static const Color plusMint = Color(0xFFDAF1DE); // accents
}
