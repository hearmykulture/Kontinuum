// lib/ui/writing_editor/blocks/block_handler.dart
import 'dart:ui' show Rect;
import 'package:flutter/material.dart';

import '../models/text_block.dart';

/// 🔔 Emitted when a bar’s blocks changed (insert/delete/update/shift/etc.)
/// `barIndex` lets listeners ignore notifications for other rows; use -1 for all.
class BlocksChangedNotification extends Notification {
  final int barIndex;
  const BlocksChangedNotification({required this.barIndex});
}

/// Callback fired when a block's head is tapped.
/// Provides the block model and the head widget's *screen-space* rect.
typedef BlockTapCallback = void Function(TextBlock block, Rect globalRect);

/// Callback allowing an inline handler to request a model update
/// (e.g. change meaning index, edit right-side text, etc.).
/// The editor should treat this as an atomic change and push history.
typedef BlockUpdateCallback = void Function(TextBlock before, TextBlock after);

/// Base interface for all inline block renderers.
/// Most implementations will return a [WidgetSpan] as the head and let
/// BarRow paint any wrapped tails using computed fragments.
abstract class BlockHandler {
  /// The block type this handler knows how to render.
  BlockType get type;

  /// Build the inline span for [block].
  ///
  /// - [baseStyle] is the text style of the surrounding paragraph; use it
  ///   for font metrics so the head aligns to the text baseline.
  /// - [onTap] should be invoked when the head is tapped; pass the *global*
  ///   rect of the head for accurate popup placement.
  /// - [minWidth] is an optional measured minimum width for the head.
  /// - [maxHeadWidth] caps the width of the head on the first line so that
  ///   following text can wrap; **handlers must honor this** (do not use
  ///   IntrinsicWidth, prefer a ConstrainedBox).
  /// - [isArmed]/[armedTick] and [isSelected] are transient visual cues.
  /// - [requestUpdate] lets the handler modify the block inline without
  ///   invoking the external editor UI (caller should push history).
  InlineSpan buildSpan({
    required BuildContext context,
    required TextBlock block,
    required TextStyle baseStyle,
    required BlockTapCallback onTap,
    double? minWidth,
    double? maxHeadWidth,
    bool isArmed = false,
    int armedTick = 0,
    bool isSelected = false,
    BlockUpdateCallback? requestUpdate,
  });
}

/// Optional capability for handlers that want their head’s *minimum width*
/// pre-measured by the editor (so layout can be stable/animated).
abstract class MeasurableBlockHandler implements BlockHandler {
  /// Return the *minimum* width (in logical px) that your head needs when
  /// rendered with [baseStyle]. This should match how the head actually
  /// paints (e.g., measure label text + padding + any fixed adornments).
  double measureMinWidth({
    required BuildContext context,
    required TextBlock block,
    required TextStyle baseStyle,
  });
}
