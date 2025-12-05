import 'package:flutter/material.dart';
import 'package:kontinuum/ui/common/safe_network_image.dart';

/// Compact header
class BlockHeader extends StatelessWidget {
  const BlockHeader({
    super.key,
    required this.blockLabel,
    required this.blockTypeLabel,
  });

  final String blockLabel;
  final String blockTypeLabel;

  @override
  Widget build(BuildContext context) {
    final String display = blockLabel.isEmpty ? 'Exercise' : blockLabel;
    final int len = display.length;
    final double titleSize = len <= 14 ? 34 : (len <= 26 ? 30 : 26);

    return Column(
      children: [
        Text(
          display,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black87,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          blockTypeLabel,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Exercise thumbnail
class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({super.key, this.url, this.size = 168});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    const double radius = 24;

    return SafeNetworkImage(
      url: url,
      width: size,
      height: size,
      radius: radius,
      backgroundColor: Colors.black.withValues(alpha: 0.04),
      placeholder: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.fitness_center,
          size: 44,
          color: Colors.black.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// Current Set HUD
class CurrentSetHUD extends StatelessWidget {
  const CurrentSetHUD({
    super.key,
    required this.setIndex,
    required this.totalSets,
    required this.targetLoadLb,
    required this.targetReps,
    required this.onLogTap,
    this.showTargetLine = false,
  });

  final int setIndex;
  final int totalSets;
  final double targetLoadLb;
  final int targetReps;
  final VoidCallback onLogTap;
  final bool showTargetLine;

  @override
  Widget build(BuildContext context) {
    String fmtLb(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Set $setIndex/$totalSets',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        if (showTargetLine) ...[
          const SizedBox(height: 4),
          Text(
            'Target: ${fmtLb(targetLoadLb)} lb × $targetReps • $totalSets sets',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.55),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ],
    );
  }
}
