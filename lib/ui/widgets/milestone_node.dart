import 'package:flutter/material.dart';

class MilestoneNode extends StatelessWidget {
  final int value;
  final bool achieved;
  final VoidCallback? onTap;

  const MilestoneNode({
    super.key,
    required this.value,
    required this.achieved,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = achieved
        ? Colors.greenAccent.shade700.withOpacity(0.9)
        : Colors.grey.shade800;
    final borderColor = achieved
        ? Colors.greenAccent.shade400
        : Colors.grey.shade600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (achieved)
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.5),
                blurRadius: 12,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              achieved ? Icons.check_circle : Icons.lock,
              color: achieved ? Colors.white : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$value',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: achieved ? Colors.white : Colors.grey.shade300,
                ),
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
