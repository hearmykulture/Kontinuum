import 'dart:ui' show Rect;
import 'package:flutter/material.dart';

import '../models/text_block.dart';
import '../blocks/block_registry.dart';
import '../blocks/block_handler.dart' show BlockHandler, MeasurableBlockHandler;

class BlockTextRenderer {
  static TextSpan build(
    BuildContext context, {
    required String text,
    required List<TextBlock> blocks,
    required void Function(TextBlock, Rect) onTapBlock,
    TextStyle? style,
    String? armedKey,
    int armedTick = 0,
    Set<String> selectedKeys = const <String>{},
    void Function(TextBlock before, TextBlock after)? requestUpdate,

    /// Per-block head width caps (stableId → px), provided by BarRow.
    Map<String, double> headWidthCaps = const {},
  }) {
    final spans = <InlineSpan>[];
    int pos = 0;

    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = defaultStyle.merge(style);

    // Validate & order blocks by start offset
    final valid =
        blocks
            .where(
              (b) => b.start >= 0 && b.end <= text.length && b.start < b.end,
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    // Pre-measure minimum widths for measurable blocks (so handlers can animate/constraint)
    final minWidths = <String, double>{};
    for (final b in valid) {
      final handler = BlockRegistry.instance.handlerFor(b.type);
      if (handler is MeasurableBlockHandler) {
        final id = _blockId(b);
        minWidths[id] = handler.measureMinWidth(
          context: context,
          block: b,
          baseStyle: effectiveStyle,
        );
      }
    }

    for (final b in valid) {
      // Plain text before the block.
      if (b.start > pos) {
        spans.add(
          TextSpan(text: text.substring(pos, b.start), style: effectiveStyle),
        );
      }

      // The block itself.
      final handler = BlockRegistry.instance.handlerFor(b.type);
      if (handler is! BlockHandler) {
        // No handler registered → just emit the raw glyph/text range.
        spans.add(
          TextSpan(text: text.substring(b.start, b.end), style: effectiveStyle),
        );
      } else {
        final id = _blockId(b);
        final isArmed = armedKey != null && armedKey == id;
        final isSelected = selectedKeys.contains(id);

        // Head cap width computed by BarRow.
        final cap = _capForId(headWidthCaps, b, fallbackId: id);
        final min = minWidths[id];

        spans.add(
          handler.buildSpan(
            context: context,
            block: b,
            baseStyle: effectiveStyle,
            onTap: onTapBlock,
            minWidth: min,
            maxHeadWidth: cap, // cap the head pill so following text wraps
            isArmed: isArmed,
            armedTick: isArmed ? armedTick : 0,
            isSelected: isSelected,
            requestUpdate: requestUpdate,
          ),
        );
      }

      pos = b.end;
    }

    // Tail after the last block.
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos), style: effectiveStyle));
    }

    return TextSpan(style: effectiveStyle, children: spans);
  }

  /// Use the stable id (preferred) for selection/paint identity.
  static String _blockId(TextBlock b) => b.stableId;

  /// Try both the stableId and legacy positional key so older callers still work.
  static double? _capForId(
    Map<String, double> caps,
    TextBlock b, {
    required String fallbackId,
  }) {
    if (caps.containsKey(fallbackId)) return caps[fallbackId];
    final legacy = '${b.type}:${b.start}:${b.end}';
    if (caps.containsKey(legacy)) return caps[legacy];
    return caps[_blockId(b)];
  }
}
