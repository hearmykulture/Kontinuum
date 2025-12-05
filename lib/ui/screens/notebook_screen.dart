import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/project_provider.dart';
import 'package:kontinuum/models/project_model.dart';
import 'package:kontinuum/ui/screens/page_screen.dart';

class NotebookScreen extends StatelessWidget {
  const NotebookScreen({
    super.key,
    required this.notebookId,
  });

  final String notebookId;

  static const Color _bg = Color(0xFF0F151A);

  @override
  Widget build(BuildContext context) {
    final Notebook? notebook =
        context.watch<ProjectProvider>().notebookById(notebookId);

    // If the notebook somehow doesn't exist (deleted while open, etc.),
    // show a simple fallback.
    if (notebook == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Notebook',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const SafeArea(
          child: Center(
            child: Text(
              'This notebook no longer exists.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final String title = notebook.title;

    void addPage() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PageScreen(
            notebookId: notebook.id,
          ),
          settings: RouteSettings(
            name: 'notebook_${notebook.id}_new_page',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: const SafeArea(
        child: Center(
          child: Text(
            'No pages yet.\nTap the + button to add a page.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addPage,
        backgroundColor: const Color(0xFF6C8CFF),
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('Add Page'),
      ),
    );
  }
}
