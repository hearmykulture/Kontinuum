import 'package:kontinuum/core/time/app_clock.dart';
// lib/models/project_model.dart
class Project {
  final String id;
  String name;
  final List<String> tracks;

  Project({
    required this.id,
    required this.name,
    List<String>? tracks,
  }) : tracks = tracks ?? [];
}

class Notebook {
  final String id;
  final String title;
  final String icon; // emoji or glyph
  final int color; // ARGB color value
  final String? projectId; // null if not linked to a project
  final List<String> tags;
  final List<String> collaborators;
  final String? password; // null if none
  final DateTime createdAt;

  Notebook({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    this.projectId,
    List<String>? tags,
    List<String>? collaborators,
    this.password,
    DateTime? createdAt,
  })  : tags = tags ?? [],
        collaborators = collaborators ?? [],
        createdAt = createdAt ?? AppClock.now();
}
