// lib/ui/writing_editor/widgets/bar_bench.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // for pointerDragAnchorStrategy

class BarBench extends StatelessWidget {
  /// The main content of the screen (your editor’s ListView, etc).
  final Widget body;

  /// Optional: handle quick-insert taps (e.g., insert at current caret).
  /// Pass a callback that accepts 'entendre' or 'simile'.
  final void Function(String data)? onQuickInsert;

  const BarBench({
    super.key,
    required this.body,
    this.onQuickInsert,
  });

  Widget _pill(String label) {
    return Material(
      color: Colors.grey[850],
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _draggablePill({
    required BuildContext scaffoldCtx,
    required String data,
    required String label,
  }) {
    final pill = _pill(label);
    return LongPressDraggable<String>(
      data: data,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Opacity(opacity: 0.9, child: pill),
      childWhenDragging: Opacity(opacity: 0.3, child: pill),
      onDragStarted: () {
        Scaffold.of(scaffoldCtx).closeEndDrawer();
        debugPrint('🛫 Drawer drag started ($data), drawer closing');
      },
      child: pill,
    );
  }

  Widget _quickInsertButton({
    required BuildContext ctx,
    required String data,
    required String label,
  }) {
    return ElevatedButton(
      onPressed: () {
        // Let the parent perform the actual insert (e.g., controller.insertBlock)
        onQuickInsert?.call(data);
        Scaffold.of(ctx).closeEndDrawer();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // editor background
      drawerScrimColor: Colors.transparent, // no scrim
      endDrawerEnableOpenDragGesture: false, // only open via button
      endDrawer: Drawer(
        backgroundColor: Colors.grey[900],
        elevation: 16,
        child: SafeArea(
          child: Builder(
            builder: (scaffoldCtx) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Draggable pills at top
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _draggablePill(
                          scaffoldCtx: scaffoldCtx,
                          data: 'entendre',
                          label: 'Entendre (drag)',
                        ),
                        _draggablePill(
                          scaffoldCtx: scaffoldCtx,
                          data: 'simile',
                          label: 'Simile (drag)',
                        ),
                      ],
                    ),
                  ),

                  // Quick-insert buttons (tap to insert at caret)
                  if (onQuickInsert != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(color: Colors.white24),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        'Quick insert',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _quickInsertButton(
                            ctx: scaffoldCtx,
                            data: 'entendre',
                            label: 'Insert Entendre',
                          ),
                          _quickInsertButton(
                            ctx: scaffoldCtx,
                            data: 'simile',
                            label: 'Insert Simile',
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(color: Colors.white24),
                  ),

                  // Menu items (placeholder)
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        ListTile(
                          tileColor: Colors.grey[800],
                          title: const Text(
                            'Option 1',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () => Scaffold.of(context).closeEndDrawer(),
                        ),
                        ListTile(
                          tileColor: Colors.grey[800],
                          title: const Text(
                            'Option 2',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () => Scaffold.of(context).closeEndDrawer(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          "✍️ Block Editor",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          Builder(
            builder: (innerCtx) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(innerCtx).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}
