// lib/ui/widgets/objective/objective_tokens.dart
import 'package:flutter/material.dart';

/// Shared design tokens & palette for objective widgets.
class ObjectiveTokens {
  // Typography / sizes
  static const double kCardTitleSize = 16;
  static const double kSheetTitleSize = 18;
  static const double kMicroSize = 12;
  static const double kMetaSize = 11;
  static const double kBadgeSize = 10.5;
  static const double kStepperNumber = 14;
  static const double kCheckSize = 30;
  static const double kRowHeight = 36;

  // Category color palette
  static const Map<String, Color> categoryColors = {
    'PRODUCTION': Colors.orange,
    'RAPPING': Colors.purple,
    'HEALTH': Colors.green,
    'KNOWLEDGE': Colors.blue,
    'NETWORKING': Colors.redAccent,
    'CONTENT': Colors.cyan,
  };
}
