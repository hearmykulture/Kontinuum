import 'package:flutter/material.dart';
import 'package:kontinuum/ui/common/safe_network_image.dart';
import 'package:kontinuum/ui/workout/workout_editor_constants.dart';

/// Page dots indicator for navigating exercises
class PageDotsIndicator extends StatelessWidget {
  const PageDotsIndicator({
    super.key,
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final int safeCount = count <= 0 ? 1 : count;
    final int safeIndex =
        index < 0 ? 0 : (index >= safeCount ? safeCount - 1 : index);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(safeCount, (i) {
        final bool active = i == safeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: active ? 18 : 8,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

/// Block header for overview screen
class OverviewBlockHeader extends StatelessWidget {
  const OverviewBlockHeader({
    super.key,
    required this.blockLabel,
    required this.blockTypeLabel,
  });

  final String blockLabel;
  final String blockTypeLabel;

  @override
  Widget build(BuildContext context) {
    final String display = blockLabel.isEmpty ? 'Block' : blockLabel;
    final int len = display.length;
    final double titleSize = len <= 14 ? 34 : (len <= 26 ? 30 : 26);

    final bool showSecondary = blockTypeLabel.trim().isNotEmpty;

    return Column(
      children: [
        Text(
          display,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kPrimaryText,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        if (showSecondary) ...[
          const SizedBox(height: 12),
          Text(
            blockTypeLabel,
            style: TextStyle(
              color: kSecondaryText.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Exercise thumbnail (overview version with dark theme)
class OverviewExerciseThumbnail extends StatelessWidget {
  const OverviewExerciseThumbnail({super.key, this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return SafeNetworkImage(
      url: url,
      width: 148,
      height: 148,
      radius: 24,
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      placeholder: Container(
        width: 148,
        height: 148,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.fitness_center,
          size: 36,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// Metric tile data model
class MetricTileData {
  const MetricTileData({
    required this.label,
    required this.value,
    required this.isPlaceholder,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final bool isPlaceholder;
  final bool fullWidth; // when true, tile expands to full row (REST overlay)
}

/// Prescription metrics grid
class PrescriptionMetricsGrid extends StatelessWidget {
  const PrescriptionMetricsGrid({super.key, required this.metrics});

  final List<MetricTileData> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    // Split into 4 grid tiles and the centered REST tile
    final List<MetricTileData> gridTiles = <MetricTileData>[];
    MetricTileData? restTile;
    for (final m in metrics) {
      if (m.fullWidth) {
        restTile ??= m;
      } else {
        gridTiles.add(m);
      }
    }

    // Space between the two grid rows; large enough so REST can sit *between*.
    const double hSpacing = 16;
    const double vSpacingBetweenRows = 36;

    final grid = LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final bool twoCols = maxWidth >= 260;
        final double halfWidth = twoCols ? (maxWidth - hSpacing) / 2 : maxWidth;

        return Wrap(
          spacing: hSpacing,
          runSpacing: vSpacingBetweenRows,
          alignment: WrapAlignment.center,
          children: [
            for (final metric in gridTiles)
              SizedBox(
                width: (!twoCols) ? maxWidth : halfWidth,
                child: _MetricTile(config: metric),
              ),
          ],
        );
      },
    );

    // Overlay REST in the vertical middle of the grid.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        grid,
        if (restTile != null)
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: _RestMetricTile(config: restTile!),
            ),
          ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.config});

  final MetricTileData config;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      color: kSecondaryText.withValues(alpha: 0.7),
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
    );
    final TextStyle valueStyle = TextStyle(
      color: config.isPlaceholder
          ? kSecondaryText.withValues(alpha: 0.55)
          : kSecondaryText.withValues(alpha: 0.95),
      fontSize: 16,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.1,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(config.label.toUpperCase(), style: labelStyle),
          const SizedBox(height: 6),
          Text(
            config.value,
            style: valueStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RestMetricTile extends StatelessWidget {
  const _RestMetricTile({required this.config});

  final MetricTileData config;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          config.label.toUpperCase(),
          style: TextStyle(
            color: kSecondaryText.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          config.value,
          style: TextStyle(
            color: config.isPlaceholder
                ? kSecondaryText.withValues(alpha: 0.55)
                : kSecondaryText.withValues(alpha: 0.95),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Empty block state indicator
class EmptyBlockState extends StatelessWidget {
  const EmptyBlockState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.fitness_center_outlined,
          size: 36,
          color: kSecondaryText.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Add an exercise to preview this block.',
          style: TextStyle(
            color: kSecondaryText.withValues(alpha: 0.8),
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
