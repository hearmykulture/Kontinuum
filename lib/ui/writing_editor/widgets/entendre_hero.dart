import 'package:flutter/material.dart'; // for pointerDragAnchorStrategy

/// The full-screen panel you morph into, with the draggable “Drag Entendre” button.
class EntendreHeroPanel extends StatelessWidget {
  final VoidCallback onAddEntendre;
  const EntendreHeroPanel({super.key, required this.onAddEntendre});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    // Feedback widget that follows your finger during the drag
    final feedback = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'Entendre',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Center(
        child: Hero(
          tag: 'entendre-hero',
          child: Material(
            color: Colors.black,
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screen.width * 0.8,
                maxHeight: screen.height * 0.8,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        BackButton(color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Add Entendre',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Drag-to-insert button
                    Center(
                      child: LongPressDraggable<String>(
                        data: 'entendre',
                        dragAnchorStrategy: pointerDragAnchorStrategy,
                        feedback: Opacity(opacity: 0.9, child: feedback),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: feedback,
                        ),
                        onDragStarted: () =>
                            debugPrint('🛫 Panel drag started'),
                        onDragEnd: (_) => Navigator.of(context).pop(),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_box),
                          label: const Text('Drag Entendre'),
                          onPressed: () {
                            onAddEntendre();
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
