// lib/ui/screens/audio/beat_bottom_player.dart
import 'package:flutter/material.dart';

/// Kept for compatibility only. No audio or waveform logic.
enum WaveformStyle { lines, filled, bars }

class BottomBeatPlayer extends StatelessWidget {
  // kept so existing call sites don't break; values are ignored
  final Object? player;
  final String? filePath;
  final double height;

  // unused props kept for API compatibility
  final WaveformStyle style;
  final bool useGradient;
  final Color playedColor;
  final Color unplayedColor;
  final Color playedGradientStart;
  final Color playedGradientEnd;
  final Color unplayedGradientStart;
  final Color unplayedGradientEnd;
  final Color playheadColor;
  final double playheadWidth;
  final double barWidth;
  final double barGap;
  final double barRadius;
  final double viewSeconds;
  final bool followPlayhead;
  final bool lockPlayheadCenter;
  final int extractPixelsPerSecond;

  const BottomBeatPlayer({
    super.key,
    this.player,
    this.filePath,
    this.height = 0, // default to no visible space
    this.style = WaveformStyle.bars,
    this.useGradient = true,
    this.playedColor = const Color(0xFF9C27B0),
    this.unplayedColor = const Color(0x809C27B0),
    this.playedGradientStart = const Color(0xFF7E57C2),
    this.playedGradientEnd = const Color(0xFFE91E63),
    this.unplayedGradientStart = const Color(0x407E57C2),
    this.unplayedGradientEnd = const Color(0x40E91E63),
    this.playheadColor = Colors.white,
    this.playheadWidth = 1.0,
    this.barWidth = 4.0,
    this.barGap = 2.0,
    this.barRadius = 2.0,
    this.viewSeconds = 10.0,
    this.followPlayhead = true,
    this.lockPlayheadCenter = true,
    this.extractPixelsPerSecond = 200,
  });

  @override
  Widget build(BuildContext context) {
    // No-op placeholder. If height > 0, it just reserves space.
    if (height <= 0) return const SizedBox.shrink();
    return SizedBox(height: height, width: double.infinity);
  }
}
