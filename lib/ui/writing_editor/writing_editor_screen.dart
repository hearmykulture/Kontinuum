// lib/ui/screens/writing_editor_screen.dart
import 'package:flutter/material.dart';

import 'block_text_editor.dart';

class WritingEditorScreen extends StatefulWidget {
  const WritingEditorScreen({super.key});

  @override
  State<WritingEditorScreen> createState() => _WritingEditorScreenState();
}

class _WritingEditorScreenState extends State<WritingEditorScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      // Editor content only — no audio picker/player
      body: SafeArea(
        bottom: false,
        child: BlockTextEditor(),
      ),
    );
  }
}
