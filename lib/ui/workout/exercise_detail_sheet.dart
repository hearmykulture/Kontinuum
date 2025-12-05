import 'package:flutter/material.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/utils/text_format.dart';

class ExerciseDetailSheet extends StatelessWidget {
  const ExerciseDetailSheet({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final hasMedia = exercise.mediaUrl != null && exercise.mediaUrl!.isNotEmpty;
    final hasInstructions = exercise.instructions.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatTitleCase(exercise.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final m in exercise.muscles)
                    _chip(formatTitleCase(m), Icons.fitness_center),
                  for (final e in exercise.equipment)
                    _chip(formatTitleCase(e), Icons.handyman_outlined),
                ],
              ),
              if (hasMedia) ...[
                const SizedBox(height: 14),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      exercise.mediaUrl!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) =>
                          const _MediaFallback(radius: 12),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const _MediaLoading(radius: 12);
                      },
                    ),
                  ),
                ),
              ],
              if (hasInstructions) ...[
                const SizedBox(height: 14),
                const Text(
                  'Instructions',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  exercise.instructions.trim(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .7),
                    height: 1.35,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: .6)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Media unavailable',
        style: TextStyle(color: Colors.black54),
      ),
    );
  }
}

class _MediaLoading extends StatelessWidget {
  const _MediaLoading({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
        ),
      ),
    );
  }
}
