// lib/ui/workout/session_widgets/session_screen_widgets.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:kontinuum/ui/workout/workout_editor_constants.dart';

const Color _kGold = Color(0xFFF1B73C);

/// Per-muscle accent colors (used for tinted wedges)
const Map<String, Color> kAxisColors = {
  'Chest': Color(0xFFF1B73C), // gold
  'Back': Color(0xFF6EC8FF), // cyan
  'Shoulders': Color(0xFFB58CFF), // purple
  'Arms': Color(0xFF7CE2B1), // mint
  'Core': Color(0xFFFF9E7C), // coral
  'Glutes': Color(0xFFFFD166), // sunflower
  'Quads': Color(0xFF6EE7F9), // aqua
  'Hamstrings': Color(0xFFEE7CFF), // magenta
};

/// Header with big title and "Estimated • Xm" row
class SessionHeaderWithEstimate extends StatelessWidget {
  const SessionHeaderWithEstimate({
    super.key,
    required this.title,
    required this.minutes,
  });

  final String title;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final String display = title.isEmpty ? 'Workout' : title;
    final int len = display.length;
    final double titleSize = len <= 14 ? 34 : (len <= 26 ? 30 : 26);

    final Color lineColor = kSecondaryText.withValues(alpha: 0.95);

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
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 18, color: lineColor),
            const SizedBox(width: 8),
            Text(
              'Estimated • ${minutes}m',
              style: TextStyle(
                color: lineColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rectangular "START/RESUME" pill that heroes to a square PLAY button
class SessionStartButton extends StatelessWidget {
  const SessionStartButton({super.key, this.onTap, this.label = 'Start'});

  final VoidCallback? onTap;
  final String label;

  static const Color _kStartGreen = Color(0xFF21D07A);
  static const String kStartHeroTag = 'workoutStartButtonHero';

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    final String upperLabel = label.toUpperCase();
    final Widget button = ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            enabled ? _kStartGreen : _kStartGreen.withValues(alpha: 0.35),
        foregroundColor: kEditorBg,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(upperLabel),
    );

    return Hero(
      tag: kStartHeroTag,
      flightShuttleBuilder: (context, anim, dir, fromCtx, toCtx) {
        final Widget from = fromCtx.widget;
        final Widget to = toCtx.widget;
        return AnimatedBuilder(
          animation: anim,
          builder: (_, __) {
            final t = Curves.easeInOutCubic.transform(anim.value);
            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(opacity: 1 - t, child: from),
                Opacity(opacity: t, child: to),
              ],
            );
          },
        );
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        label: '${label.trim().isEmpty ? 'Start' : label.trim()} workout',
        child: Material(type: MaterialType.transparency, child: button),
      ),
    );
  }
}

/// Simple session action button (notes, edit, etc.)
class SessionScreenActionButton extends StatelessWidget {
  const SessionScreenActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Color foreColor = active
        ? Colors.white
        : Colors.white.withValues(alpha: enabled ? 0.85 : 0.35);
    final Color background = active
        ? kCardText.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: enabled ? 0.08 : 0.04);
    final Color borderColor = active
        ? kCardText.withValues(alpha: 0.38)
        : Colors.white.withValues(alpha: enabled ? 0.12 : 0.05);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTapHint: enabled ? 'Activate' : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: foreColor),
        ),
      ),
    );
  }
}

/// Difficulty rating section with stars (used in some contexts)
class DifficultyRatingSection extends StatelessWidget {
  const DifficultyRatingSection({super.key, required this.rating});

  final double? rating;

  @override
  Widget build(BuildContext context) {
    final double r = (rating ?? 0).clamp(0, 5);
    final String rText = r.toStringAsFixed(1);

    return Column(
      children: [
        _StarRow(rating: r),
        const SizedBox(height: 8),
        Text(
          rText,
          style: const TextStyle(
            color: kPrimaryText,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Difficulty',
          style: TextStyle(
            color: kSecondaryText.withValues(alpha: 0.9),
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final double rating; // 0..5

  @override
  Widget build(BuildContext context) {
    final List<Widget> stars = <Widget>[];
    for (int i = 1; i <= 5; i++) {
      final double diff = rating - (i - 1);
      final IconData icon = diff >= 1.0
          ? Icons.star_rounded
          : (diff >= 0.5 ? Icons.star_half_rounded : Icons.star_border_rounded);
      stars.add(
        Icon(
          icon,
          size: 26,
          color: _kGold.withValues(
            alpha: icon == Icons.star_border_rounded ? 0.45 : 1.0,
          ),
        ),
      );
      if (i != 5) stars.add(const SizedBox(width: 6));
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: stars);
  }
}

/// Polygon radar with layered glow + optional per-muscle colored wedges
class ExerciseRadarChart extends StatelessWidget {
  const ExerciseRadarChart({
    super.key,
    required this.coverage,
    required this.accentColor,
    this.colorizeWedges = true,
  });

  final Map<String, double> coverage;
  final Color accentColor;
  final bool colorizeWedges;

  static const List<String> _axes = <String>[
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Core',
    'Glutes',
    'Quads',
    'Hamstrings',
  ];

  List<RadarEntry> _entriesFor(
    Map<String, double> cov, {
    double scale = 1.0,
  }) {
    return _axes
        .map(
          (a) => RadarEntry(
            value: ((cov[a] ?? 0.0) * scale).clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<RadarEntry> base = _entriesFor(coverage, scale: 1.0);
    final bool hasData = base.any((e) => e.value > 0);

    if (!hasData) {
      return const Center(
        child: Text(
          'Coverage data unavailable',
          style: TextStyle(
            color: Color(0x99FFFFFF),
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      );
    }

    final Color grid = Colors.white.withValues(alpha: 0.12);
    final Color tick = Colors.white.withValues(alpha: 0.08);
    final Color labelColor = Colors.white.withValues(alpha: 0.78);

    final List<RadarDataSet> sets = <RadarDataSet>[
      // Inner soft fill
      RadarDataSet(
        dataEntries: _entriesFor(coverage, scale: 0.55),
        fillColor: accentColor.withValues(alpha: 0.12),
        borderColor: Colors.transparent,
        borderWidth: 0,
        entryRadius: 0,
      ),
      // Mid ring
      RadarDataSet(
        dataEntries: _entriesFor(coverage, scale: 0.80),
        fillColor: accentColor.withValues(alpha: 0.18),
        borderColor: accentColor.withValues(alpha: 0.35),
        borderWidth: 1.2,
        entryRadius: 0,
      ),
    ];

    // Optional colored wedges per axis (beneath final outline)
    if (colorizeWedges) {
      for (int i = 0; i < _axes.length; i++) {
        final String axis = _axes[i];
        final double v = (coverage[axis] ?? 0.0).clamp(0.0, 1.0);
        if (v <= 0) continue;

        final Color c = (kAxisColors[axis] ?? accentColor);
        final List<RadarEntry> tri = List<RadarEntry>.generate(
          _axes.length,
          (j) => RadarEntry(value: j == i ? v : 0.0),
        );

        sets.add(
          RadarDataSet(
            dataEntries: tri,
            fillColor: c.withValues(alpha: 0.22),
            borderColor: c.withValues(alpha: 0.85),
            borderWidth: 1.1,
            entryRadius: 0,
          ),
        );
      }
    }

    // Final crisp outline on top
    sets.add(
      RadarDataSet(
        dataEntries: base,
        fillColor: accentColor.withValues(alpha: 0.24),
        borderColor: accentColor.withValues(alpha: 0.95),
        borderWidth: 2.2,
        entryRadius: 0,
      ),
    );

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        radarBackgroundColor: Colors.transparent,
        radarBorderData: BorderSide(
          color: Colors.white.withValues(alpha: 0.04),
          width: 0.6,
        ),
        borderData: FlBorderData(show: false),
        tickCount: 6,
        ticksTextStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.42),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
        tickBorderData: BorderSide(color: tick, width: 0.9),
        gridBorderData: BorderSide(color: grid, width: 1.0),
        titlePositionPercentageOffset: 0.22,
        titleTextStyle: TextStyle(
          color: labelColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.15,
        ),
        getTitle: (index, angle) => RadarChartTitle(
          text: _axes[index],
          angle: angle,
        ),
        radarTouchData: RadarTouchData(enabled: false),
        dataSets: sets,
      ),
    );
  }
}

/// Empty state indicator
class EmptyWorkoutState extends StatelessWidget {
  const EmptyWorkoutState({super.key});

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
          'Add an exercise to preview this workout.',
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
