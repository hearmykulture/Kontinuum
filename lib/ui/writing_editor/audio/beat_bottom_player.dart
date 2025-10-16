import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' show basename;
import 'package:path_provider/path_provider.dart';

enum WaveformStyle { lines, filled, bars }

class BottomBeatPlayer extends StatefulWidget {
  final AudioPlayer player;
  final String? filePath;
  final double height;

  // style
  final WaveformStyle style;
  final bool useGradient;

  // flat colors
  final Color playedColor;
  final Color unplayedColor;

  // gradients
  final Color playedGradientStart;
  final Color playedGradientEnd;
  final Color unplayedGradientStart;
  final Color unplayedGradientEnd;

  // playhead
  final Color playheadColor;
  final double playheadWidth;

  // bars
  final double barWidth;
  final double barGap;
  final double barRadius;

  // viewport/zoom/follow
  /// Seconds of audio visible across the canvas. Smaller = more zoom.
  final double viewSeconds;

  /// If true, keeps the viewport following the audio position.
  final bool followPlayhead;

  /// If true, keeps playhead near the center (until start/end boundaries).
  final bool lockPlayheadCenter;

  /// Extraction resolution (pixels/second) for just_waveform.
  final int extractPixelsPerSecond;

  const BottomBeatPlayer({
    super.key,
    required this.player,
    required this.filePath,
    this.height = 120,

    // style
    this.style = WaveformStyle.bars,
    this.useGradient = true,

    // colors
    this.playedColor = const Color(0xFF9C27B0),
    this.unplayedColor = const Color(0x809C27B0),

    // gradients
    this.playedGradientStart = const Color(0xFF7E57C2),
    this.playedGradientEnd = const Color(0xFFE91E63),
    this.unplayedGradientStart = const Color(0x407E57C2),
    this.unplayedGradientEnd = const Color(0x40E91E63),

    // playhead
    this.playheadColor = Colors.white,
    this.playheadWidth = 1.0,

    // bars
    this.barWidth = 4.0,
    this.barGap = 2.0,
    this.barRadius = 2.0,

    // viewport/zoom/follow
    this.viewSeconds = 10.0,
    this.followPlayhead = true,
    this.lockPlayheadCenter = true,
    this.extractPixelsPerSecond = 200,
  });

  @override
  State<BottomBeatPlayer> createState() => _BottomBeatPlayerState();
}

class _BottomBeatPlayerState extends State<BottomBeatPlayer> {
  Waveform? _waveform;
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    if (widget.filePath != null) _generateWaveform(widget.filePath!);
  }

  @override
  void didUpdateWidget(covariant BottomBeatPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filePath != oldWidget.filePath ||
        widget.extractPixelsPerSecond != oldWidget.extractPixelsPerSecond) {
      _waveform = null;
      _extracting = false;
      if (widget.filePath != null) {
        _generateWaveform(widget.filePath!);
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _generateWaveform(String path) async {
    if (_extracting) return;
    try {
      final f = File(path);
      if (!f.existsSync()) return;

      setState(() => _extracting = true);

      final tmp = await getTemporaryDirectory();
      final out = File('${tmp.path}/${basename(path)}.wf');
      if (out.existsSync()) {
        try {
          await out.delete();
        } catch (_) {}
      }

      final stream = JustWaveform.extract(
        audioInFile: f,
        waveOutFile: out,
        zoom: WaveformZoom.pixelsPerSecond(widget.extractPixelsPerSecond),
      );

      Waveform? finalWf;
      await for (final p in stream) {
        if (p.waveform != null) finalWf = p.waveform;
      }

      if (!mounted) return;
      setState(() {
        _waveform = finalWf;
        _extracting = false;
      });
    } catch (_) {
      if (mounted) setState(() => _extracting = false);
    }
  }

  void _seekFromDx(
    double dx,
    double width,
    Duration total,
    double leftPixel,
    double pixelsPerCanvasPx,
  ) {
    // Convert a tap within the viewport back to absolute position.
    final wfX = (dx * pixelsPerCanvasPx) + leftPixel; // absolute waveform pixel
    final ratio = (_waveform == null || _waveform!.length == 0)
        ? 0.0
        : (wfX / _waveform!.length).clamp(0.0, 1.0);
    widget.player.seek(
      Duration(milliseconds: (total.inMilliseconds * ratio).round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filePath == null || widget.height <= 0) {
      return const SizedBox.shrink();
    }

    return Material(
      color: const Color(0xFF0E0E0E),
      elevation: 6,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _waveform == null
            ? (_extracting
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const SizedBox())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return StreamBuilder<Duration>(
                    stream: widget.player.positionStream,
                    builder: (context, posSnap) {
                      final position = posSnap.data ?? Duration.zero;
                      final total = widget.player.duration ?? Duration.zero;

                      // Viewport in waveform pixel units
                      final wf = _waveform!;
                      final wfPixels = wf.length;
                      final wfPps = widget.extractPixelsPerSecond.toDouble();
                      // Convert requested seconds to pixels (clamped to total waveform)
                      final viewPixels = (widget.viewSeconds * wfPps).clamp(
                        50,
                        wfPixels.toDouble(),
                      );

                      // Where should the viewport start?
                      final posPixel = wf.positionToPixel(position);
                      double leftPixel;
                      double playheadX;
                      if (widget.followPlayhead) {
                        if (widget.lockPlayheadCenter) {
                          // keep playhead visually centered, except near edges
                          final idealLeft = posPixel - (viewPixels / 2);
                          leftPixel = idealLeft.clamp(
                            0,
                            (wfPixels - viewPixels).toDouble(),
                          );
                          // playhead is centered unless we're clamped at edges
                          final clampedLeft = idealLeft != leftPixel;
                          playheadX = clampedLeft && leftPixel == 0
                              ? posPixel * (constraints.maxWidth / viewPixels)
                              : (clampedLeft &&
                                    leftPixel == wfPixels - viewPixels)
                              ? (posPixel - leftPixel) *
                                    (constraints.maxWidth / viewPixels)
                              : constraints.maxWidth / 2;
                        } else {
                          // playhead at its proportional position within the viewport
                          leftPixel = (posPixel - (viewPixels * 0.1)).clamp(
                            0,
                            (wfPixels - viewPixels).toDouble(),
                          );
                          playheadX =
                              (posPixel - leftPixel) *
                              (constraints.maxWidth / viewPixels);
                        }
                      } else {
                        // static viewport (full track)
                        leftPixel = 0;
                        playheadX =
                            (posPixel / wfPixels) * constraints.maxWidth;
                      }

                      final pixelsPerCanvasPx =
                          viewPixels / constraints.maxWidth;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => _seekFromDx(
                          d.localPosition.dx,
                          constraints.maxWidth,
                          total,
                          leftPixel,
                          pixelsPerCanvasPx,
                        ),
                        onHorizontalDragUpdate: (d) => _seekFromDx(
                          d.localPosition.dx,
                          constraints.maxWidth,
                          total,
                          leftPixel,
                          pixelsPerCanvasPx,
                        ),
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, widget.height),
                          painter: _WavePainter(
                            waveform: wf,
                            // viewport
                            leftPixel: leftPixel,
                            viewPixels: viewPixels.toDouble(),
                            playheadX: playheadX.clamp(
                              0.0,
                              constraints.maxWidth,
                            ),
                            // style
                            style: widget.style,
                            useGradient: widget.useGradient,
                            playedColor: widget.playedColor,
                            unplayedColor: widget.unplayedColor,
                            playedGradientStart: widget.playedGradientStart,
                            playedGradientEnd: widget.playedGradientEnd,
                            unplayedGradientStart: widget.unplayedGradientStart,
                            unplayedGradientEnd: widget.unplayedGradientEnd,
                            // playhead
                            playheadColor: widget.playheadColor,
                            playheadWidth: widget.playheadWidth,
                            // bars
                            barWidth: widget.barWidth,
                            barGap: widget.barGap,
                            barRadius: widget.barRadius,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Waveform waveform;

  // viewport (in waveform pixel units)
  final double leftPixel; // inclusive
  final double viewPixels; // width of viewport
  final double playheadX; // canvas x for playhead

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

  // bars
  final double barWidth;
  final double barGap;
  final double barRadius;

  _WavePainter({
    required this.waveform,
    required this.leftPixel,
    required this.viewPixels,
    required this.playheadX,
    required this.style,
    required this.useGradient,
    required this.playedColor,
    required this.unplayedColor,
    required this.playedGradientStart,
    required this.playedGradientEnd,
    required this.unplayedGradientStart,
    required this.unplayedGradientEnd,
    required this.playheadColor,
    required this.playheadWidth,
    required this.barWidth,
    required this.barGap,
    required this.barRadius,
  });

  Shader _shader(Size size, Color a, Color b) => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [a, b],
  ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 1 || size.height <= 1) return;

    final pixels = waveform.length;
    if (pixels == 0) return;

    final yMid = size.height / 2;

    // normalization
    final is8Bit = (waveform.flags & 1) == 1;
    final norm = is8Bit ? 128.0 : 32768.0;

    // viewport mapping: canvas x → waveform pixel index
    final pixelsPerCanvasPx = viewPixels / size.width;

    // paints
    final playedPaint = Paint()
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final unplayedPaint = Paint()
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    if (useGradient) {
      playedPaint.shader = _shader(
        size,
        playedGradientStart,
        playedGradientEnd,
      );
      unplayedPaint.shader = _shader(
        size,
        unplayedGradientStart,
        unplayedGradientEnd,
      );
    } else {
      playedPaint.color = playedColor;
      unplayedPaint.color = unplayedColor;
    }

    if (style == WaveformStyle.lines) {
      for (double x = 0; x < size.width; x += 1) {
        final wfIndex = (leftPixel + x * pixelsPerCanvasPx).toInt().clamp(
          0,
          pixels - 1,
        );
        final min = waveform.getPixelMin(wfIndex);
        final max = waveform.getPixelMax(wfIndex);

        final ampTop = (max.abs() / norm).clamp(0.0, 1.0);
        final ampBot = (min.abs() / norm).clamp(0.0, 1.0);

        final top = yMid - (ampTop * yMid);
        final bot = yMid + (ampBot * yMid);

        final paint = (x <= playheadX) ? playedPaint : unplayedPaint;
        canvas.drawLine(Offset(x, top), Offset(x, bot), paint);
      }
    } else if (style == WaveformStyle.filled) {
      final topPath = Path();
      final bottomPath = Path();
      for (double x = 0; x < size.width; x += 1) {
        final idx = (leftPixel + x * pixelsPerCanvasPx).toInt().clamp(
          0,
          pixels - 1,
        );
        final max = waveform.getPixelMax(idx);
        final y = yMid - ((max.abs() / norm).clamp(0.0, 1.0) * yMid);
        if (x == 0)
          topPath.moveTo(x, y);
        else
          topPath.lineTo(x, y);
      }
      for (double x = size.width - 1; x >= 0; x -= 1) {
        final idx = (leftPixel + x * pixelsPerCanvasPx).toInt().clamp(
          0,
          pixels - 1,
        );
        final min = waveform.getPixelMin(idx);
        final y = yMid + ((min.abs() / norm).clamp(0.0, 1.0) * yMid);
        if (x == size.width - 1)
          bottomPath.moveTo(x, y);
        else
          bottomPath.lineTo(x, y);
      }
      final fillPath = Path()
        ..addPath(topPath, Offset.zero)
        ..addPath(bottomPath, Offset.zero)
        ..close();

      final unplayedFill = Paint()..style = PaintingStyle.fill;
      if (useGradient) {
        unplayedFill.shader = _shader(
          size,
          unplayedGradientStart,
          unplayedGradientEnd,
        );
      } else {
        unplayedFill.color = unplayedColor;
      }
      canvas.drawPath(fillPath, unplayedFill);

      if (playheadX > 0) {
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(0, 0, playheadX, size.height));
        final playedFill = Paint()..style = PaintingStyle.fill;
        if (useGradient) {
          playedFill.shader = _shader(
            size,
            playedGradientStart,
            playedGradientEnd,
          );
        } else {
          playedFill.color = playedColor;
        }
        canvas.drawPath(fillPath, playedFill);
        canvas.restore();
      }
    } else {
      // bars
      final barStep = (barWidth + barGap).clamp(1.0, size.width);
      final sampleWindow = (pixelsPerCanvasPx * barWidth)
          .clamp(1.0, 20.0)
          .round();

      for (double x = 0; x < size.width; x += barStep) {
        final centerX = x + barWidth / 2.0;
        final baseIdx = (leftPixel + centerX * pixelsPerCanvasPx).toInt();

        int minSum = 0, maxSum = 0, cnt = 0;
        for (int k = 0; k < sampleWindow; k++) {
          final idx = (baseIdx + k).clamp(0, pixels - 1);
          minSum += waveform.getPixelMin(idx);
          maxSum += waveform.getPixelMax(idx);
          cnt++;
        }
        final minAvg = (minSum / cnt);
        final maxAvg = (maxSum / cnt);

        final ampTop = (maxAvg.abs() / norm).clamp(0.0, 1.0);
        final ampBot = (minAvg.abs() / norm).clamp(0.0, 1.0);

        final topY = yMid - (ampTop * yMid);
        final botY = yMid + (ampBot * yMid);
        final barH = (botY - topY).clamp(1.0, size.height);

        final paint = (centerX <= playheadX)
            ? (useGradient
                  ? (Paint()
                      ..shader = _shader(
                        size,
                        playedGradientStart,
                        playedGradientEnd,
                      ))
                  : (Paint()..color = playedColor))
            : (useGradient
                  ? (Paint()
                      ..shader = _shader(
                        size,
                        unplayedGradientStart,
                        unplayedGradientEnd,
                      ))
                  : (Paint()..color = unplayedColor));

        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, topY, barWidth, barH),
          topLeft: Radius.circular(barRadius),
          topRight: Radius.circular(barRadius),
          bottomLeft: Radius.circular(barRadius),
          bottomRight: Radius.circular(barRadius),
        );
        canvas.drawRRect(rect, paint);
      }
    }

    // playhead
    final ph = Paint()
      ..color = playheadColor
      ..strokeWidth = playheadWidth;
    canvas.drawLine(Offset(playheadX, 0), Offset(playheadX, size.height), ph);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.waveform != waveform ||
      old.leftPixel != leftPixel ||
      old.viewPixels != viewPixels ||
      old.playheadX != playheadX ||
      old.style != style ||
      old.useGradient != useGradient ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor ||
      old.playedGradientStart != playedGradientStart ||
      old.playedGradientEnd != playedGradientEnd ||
      old.unplayedGradientStart != unplayedGradientStart ||
      old.unplayedGradientEnd != unplayedGradientEnd ||
      old.playheadColor != playheadColor ||
      old.playheadWidth != playheadWidth ||
      old.barWidth != barWidth ||
      old.barGap != barGap ||
      old.barRadius != barRadius;
}
