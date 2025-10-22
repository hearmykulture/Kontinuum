// lib/ui/screens/task_editor/checklist.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Model for a single checklist row (controller + focus + done state).
class ChecklistItemModel {
  ChecklistItemModel(String initial)
      : controller = TextEditingController(text: initial),
        key = UniqueKey();

  final Key key;
  final TextEditingController controller;
  final FocusNode focusNode = FocusNode();
  // Local row state; rows listen to this instead of parent setState
  final ValueNotifier<bool> done = ValueNotifier<bool>(false);

  void dispose() {
    controller.dispose();
    focusNode.dispose();
    done.dispose();
  }
}

/// The “Add item” rounded tile.
class AddItemTile extends StatelessWidget {
  const AddItemTile({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return const RoundedTile(
      height: 48,
      radius: 22,
      child: _AddItemBody(),
    ).wrapOnTap(onAdd);
  }
}

class _AddItemBody extends StatelessWidget {
  const _AddItemBody();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.add_rounded, color: Colors.white, size: 22),
        SizedBox(width: 10),
        Text(
          'Add item',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Visual row for a checklist entry.
class ChecklistRow extends StatelessWidget {
  const ChecklistRow({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.doneListenable,
    required this.onToggle,
    required this.onSubmitted,
    required this.onDelete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueListenable<bool> doneListenable;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final void Function(bool isLastRow) onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          InkWell(
            onTap: onToggle,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: ValueListenableBuilder<bool>(
                valueListenable: doneListenable,
                builder: (_, done, __) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: done
                      ? const Icon(
                          Icons.check_circle,
                          key: ValueKey('on'),
                          color: Colors.white,
                          size: 22,
                        )
                      : const Icon(
                          Icons.circle_outlined,
                          key: ValueKey('off'),
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Subtask',
                hintStyle: TextStyle(color: Color(0x66FFFFFF)),
                border: InputBorder.none,
                isCollapsed: true,
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => onSubmitted(true),
              inputFormatters: [
                FilteringTextInputFormatter.singleLineFormatter,
                LengthLimitingTextInputFormatter(80),
              ],
            ),
          ),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(14),
            child: const Padding(
              padding: EdgeInsets.all(6.0),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xCCFFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RemovedChecklistRow extends StatelessWidget {
  const RemovedChecklistRow({
    super.key,
    required this.text,
    required this.done,
    required this.animation,
  });

  final String text;
  final bool done;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 0.85).animate(curved),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF232323),
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: const [
                Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(
                    Icons.circle_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// small utility: disable glow on iOS style scrolling
class NoGlowScrollBehavior extends ScrollBehavior {
  const NoGlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // no glow
  }
}

class RoundedTile extends StatelessWidget {
  const RoundedTile(
      {super.key, required this.child, this.height = 56, this.radius = 28});
  final Widget child;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

/// Syntactic sugar to attach onTap to const widgets without rebuilding callers.
extension InkTapExt on Widget {
  Widget wrapOnTap(VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: this,
      );
}
