import 'package:flutter/material.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/ui/common/safe_network_image.dart';
import 'package:kontinuum/utils/text_format.dart';

class ExerciseList extends StatelessWidget {
  const ExerciseList({
    super.key,
    required this.exercises,
    required this.controller,
    required this.highlightedIndex,
    required this.selectedIds,
    this.onHighlight,
    this.onToggleSelect,
    this.enableInteractions = true,
  });

  /// Slightly tighter row height to fit more results while leaving space for
  /// two lines of text when needed.
  static const double itemExtent = 74.0;

  final List<Exercise> exercises;
  final ScrollController controller;
  final int highlightedIndex;
  final Set<String> selectedIds;
  final ValueChanged<int>? onHighlight;
  final ValueChanged<Exercise>? onToggleSelect;
  final bool enableInteractions;

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView.builder(
      controller: controller,
      itemExtent: itemExtent,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: exercises.length,
      cacheExtent: 800,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final bool highlighted = index == highlightedIndex;
        final bool selected = selectedIds.contains(exercise.id);
        final String displayName = formatTitleCase(exercise.name);
        final String subtitle = _buildSubtitle(exercise);
        final String? thumbUrl = _resolveThumbUrl(exercise);
        final Color rowColor = selected
            ? const Color(0xFFE8F1FF)
            : (highlighted ? const Color(0xFFF4F4F6) : Colors.transparent);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: rowColor,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: enableInteractions && onToggleSelect != null
                  ? () {
                      onHighlight?.call(index);
                      onToggleSelect!(exercise);
                    }
                  : null,
              borderRadius: BorderRadius.circular(14),
              onHover: enableInteractions && onHighlight != null
                  ? (hovering) {
                      if (hovering) onHighlight!(index);
                    }
                  : null,
              onTapDown: enableInteractions && onHighlight != null
                  ? (_) => onHighlight!(index)
                  : null,
              onFocusChange: enableInteractions && onHighlight != null
                  ? (hasFocus) {
                      if (hasFocus) onHighlight!(index);
                    }
                  : null,
              child: Semantics(
                label: displayName,
                hint: subtitle,
                selected: selected,
                button: true,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(
                    children: <Widget>[
                      SafeNetworkImage(
                        url: thumbUrl,
                        width: 38,
                        height: 38,
                        radius: 10,
                        fit: BoxFit.contain, // avoid cropping
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                      ),
                      const SizedBox(width: 10),
                      AnimatedOpacity(
                        opacity: selected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF2F7DFF),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xDD000000),
                                fontWeight: highlighted
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 14.5,
                                letterSpacing: 0.2,
                                height: 1.12,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                height: 1.12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black.withValues(alpha: 0.28),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String? _resolveThumbUrl(Exercise exercise) {
    final String? url = exercise.mediaUrl;
    if (url == null || url.isEmpty || !url.startsWith('http')) {
      return null;
    }
    return url;
  }

  String _buildSubtitle(Exercise exercise) {
    final List<String> parts = <String>[];
    if (exercise.muscles.isNotEmpty) {
      parts.add(
        exercise.muscles.take(2).map(_formatLabel).join(', '),
      );
    }
    if (exercise.equipment.isNotEmpty) {
      parts.add(
        exercise.equipment.take(2).map(_formatLabel).join(', '),
      );
    }
    if (parts.isEmpty) return 'No tags';
    return parts.join(' • ');
  }

  String _formatLabel(String raw) => formatTitleCase(raw);
}
