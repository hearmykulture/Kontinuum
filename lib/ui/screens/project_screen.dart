import 'package:flutter/material.dart';
import 'package:kontinuum/ui/writing_editor/block_text_editor.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen>
    with TickerProviderStateMixin {
  static const Color kBg = Color(0xFF0F151A);
  static const Color kCard = Color(0xFF0A0E11);
  static const Color kAccent = Color(0xFF6C8CFF);

  final List<String> _tracks = [];
  final TextEditingController _nameCtrl = TextEditingController();

  void _addTrack() {
    setState(() => _tracks.add('Track ${_tracks.length + 1}'));
  }

  Future<void> _renameTrack(int index) async {
    final controller = TextEditingController(text: _tracks[index]);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: kCard,
          title: const Text(
            'Rename Track',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Track name',
              hintStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: kAccent),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() => _tracks[index] = newName);
    }
  }

  void _openEditorForTrack(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BlockTextEditor(),
        settings: RouteSettings(name: 'editor_track_${index + 1}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = const Color(0xFF0C1216);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('New Project', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'create_project_card',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 180,
                        height: 180,
                        color: kCard,
                        alignment: Alignment.center,
                        child: const Text(
                          'Cover',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Project Name',
                            hintStyle: const TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                            ),
                            filled: true,
                            fillColor: kCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tracks: ${_tracks.length}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Status: Work in Progress',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                child: Column(
                  children: [
                    for (int i = 0; i < _tracks.length; i++) ...[
                      _TrackPill(
                        label: _tracks[i],
                        index: i,
                        badgeColor: badgeColor,
                        onRename: () => _renameTrack(i),
                        onOpenEditor: () => _openEditorForTrack(i),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _AddPill(
                      count: _tracks.length,
                      badgeColor: badgeColor,
                      onTap: _addTrack,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPill extends StatelessWidget {
  const _AddPill({
    required this.count,
    required this.badgeColor,
    required this.onTap,
  });

  final int count;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProjectScreenState.kCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.add_circle_rounded,
                color: _ProjectScreenState.kAccent.withOpacity(0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackPill extends StatelessWidget {
  const _TrackPill({
    required this.label,
    required this.index,
    required this.badgeColor,
    required this.onRename,
    required this.onOpenEditor,
  });

  final String label;
  final int index;
  final Color badgeColor;
  final VoidCallback onRename;
  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProjectScreenState.kCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onLongPress: onRename,
        onTap: onOpenEditor,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onOpenEditor,
                style: FilledButton.styleFrom(
                  backgroundColor: _ProjectScreenState.kAccent.withOpacity(
                    0.16,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Write'),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Rename',
                onPressed: onRename,
                icon: const Icon(Icons.edit, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
