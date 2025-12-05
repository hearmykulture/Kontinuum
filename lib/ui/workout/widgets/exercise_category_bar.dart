import 'package:flutter/material.dart';

class ExerciseCategoryBar extends StatelessWidget {
  const ExerciseCategoryBar({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
    required this.scrollController,
    required this.itemKeys,
  });

  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ScrollController scrollController;
  final List<GlobalKey> itemKeys;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE7E7E7)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < categories.length; i++) ...<Widget>[
              _Segment(
                key: itemKeys[i],
                label: categories[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
              if (i != categories.length - 1)
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.black.withValues(alpha: 0.08),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Colors.white;
    final Color activeBackground = Colors.black87;
    final Color inactiveColor = Colors.black54;

    return Material(
      color: selected ? activeBackground : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? activeColor : inactiveColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
