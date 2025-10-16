import 'package:flutter/material.dart';
import '../core/editor_layout.dart';

class EditorHeader extends StatelessWidget {
  final VoidCallback? onLoadBeat;
  final bool isLoadingBeat;

  const EditorHeader({super.key, this.onLoadBeat, this.isLoadingBeat = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: EditorLayout.headerHeight(),
      padding: const EdgeInsets.only(
        left:
            EditorLayout.outerPadding +
            EditorLayout.numColumnWidth +
            EditorLayout.textLeftPadding,
        right: EditorLayout.outerPadding,
        top: 16,
      ),
      child: Row(
        children: [
          const Expanded(
            child: TextField(
              decoration: InputDecoration(border: InputBorder.none),
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          const SizedBox(width: 16),
          const SizedBox(
            width: 120,
            child: TextField(
              decoration: InputDecoration(border: InputBorder.none),
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.library_music, color: Colors.white),
            tooltip: 'Load Beat',
            onPressed: (!isLoadingBeat && onLoadBeat != null)
                ? onLoadBeat
                : null,
          ),
        ],
      ),
    );
  }
}
