import 'package:flutter/material.dart';

/// Single source of truth for category colors.
class CategoryTheme {
  static const Color networking = Color(0xFF11A08D); // matches your teal
  static Color colorFor(String idOrName) {
    switch (idOrName.toUpperCase()) {
      case 'RAPPING':
        return Colors.redAccent;
      case 'PRODUCTION':
        return Colors.blueAccent;
      case 'HEALTH':
        return Colors.greenAccent;
      case 'KNOWLEDGE':
        return Colors.deepPurpleAccent;
      case 'NETWORKING':
        return networking;
      default:
        return Colors.grey; // fallback
    }
  }
}

/// Reusable pill badge that matches the XP bar look.
class CategoryBadge extends StatelessWidget {
  final String categoryId; // e.g. "KNOWLEDGE"
  final String? text; // optional custom label
  final EdgeInsets padding;
  final double radius;

  const CategoryBadge({
    super.key,
    required this.categoryId,
    this.text,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final c = CategoryTheme.colorFor(categoryId);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.withOpacity(0.45), width: 1.1),
      ),
      child: Text(
        (text ?? categoryId).toUpperCase(),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
