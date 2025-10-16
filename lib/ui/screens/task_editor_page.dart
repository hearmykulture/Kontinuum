// lib/ui/screens/task_editor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // for ValueListenable/ValueNotifier
import 'package:kontinuum/ui/widgets/task/task_options_panel.dart';

const double _kBarH = 44;

/// Returned to the caller when saving a task.
class TaskEditorResult {
  final String title;
  final bool repeatOnCompletion;
  final bool hasReminder;
  final bool hasDeadline;
  final List<ChecklistEntry> checklist;
  final DateTime? date; // null => No Date / Someday
  final bool someday; // explicit Someday flag (distinct from No Date)

  const TaskEditorResult({
    required this.title,
    required this.repeatOnCompletion,
    required this.hasReminder,
    required this.hasDeadline,
    required this.checklist,
    required this.date,
    required this.someday,
  });
}

/// A single checklist entry (subtask).
class ChecklistEntry {
  final String text;
  final bool done;
  const ChecklistEntry({required this.text, required this.done});
}

/// Full-screen “Create Task” / “View Task” page (styled to match Add Event).
class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({
    super.key,
    this.initialTitle,
    this.autofocusTitle = true,
    this.showDelete = false,
    this.onDelete,

    /// Seed the editor when reopening an existing task
    this.initialOptions,
    this.initialChecklist,
  });

  final String? initialTitle;
  final bool autofocusTitle;
  final bool showDelete;
  final VoidCallback? onDelete;

  /// When editing
  final TaskOptionsValue? initialOptions;
  final List<ChecklistEntry>? initialChecklist;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();

  // Extracted options state.
  final TaskOptionsController _opts = TaskOptionsController();

  bool _closing = false;
  bool _popped = false;

  // ----- Checklist state + animations -----
  final _listKey = GlobalKey<AnimatedListState>();
  final List<_ChecklistItem> _items = <_ChecklistItem>[];

  void _addItem([String initial = '']) {
    final wasEmpty = _items.isEmpty;
    final index = _items.length;
    final item = _ChecklistItem(initial);
    _items.insert(index, item);
    _listKey.currentState?.insertItem(
      index,
      duration: const Duration(milliseconds: 220),
    );
    if (wasEmpty) setState(() {}); // only rebuild when empty->nonempty
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => item.focusNode.requestFocus(),
    );
  }

  void _toggleItem(int i) {
    if (i < 0 || i >= _items.length) return;
    _items[i].done.value =
        !_items[i].done.value; // row listens; no parent rebuild
  }

  void _removeItemAt(int index) {
    if (index < 0 || index >= _items.length) return;
    final willBeEmpty = _items.length == 1;
    final removed = _items.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _RemovedChecklistRow(
        text: removed.controller.text,
        done: removed.done.value,
        animation: animation,
      ),
      duration: const Duration(milliseconds: 220),
    );
    if (willBeEmpty) setState(() {}); // only rebuild when nonempty->empty
    removed.dispose();
  }

  void _removeEmptyTrailing() {
    while (_items.isNotEmpty && _items.last.controller.text.trim().isEmpty) {
      _removeItemAt(_items.length - 1);
    }
  }

  // ----- Nav helpers -----
  void _requestKeyboard() {
    _titleFocus.requestFocus();
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  void _close() {
    if (_closing || _popped) return;
    _closing = true;
    _popped = true;
    Navigator.of(context).pop();
  }

  void _save() {
    if (_closing || _popped) return;
    _removeEmptyTrailing();

    final v = _opts.value;

    final title = _titleCtrl.text.trim().isEmpty
        ? 'Task'
        : _titleCtrl.text.trim();
    final list = _items
        .map(
          (e) => ChecklistEntry(
            text: e.controller.text.trim(),
            done: e.done.value,
          ),
        )
        .where((e) => e.text.isNotEmpty)
        .toList(growable: false);

    _closing = true;
    _popped = true;
    Navigator.of(context).pop(
      TaskEditorResult(
        title: title,
        repeatOnCompletion: v.repeatsDaily,
        hasReminder: v.hasReminder,
        hasDeadline: v.hasDeadline,
        checklist: list,
        date: v.someday ? null : v.date,
        someday: v.someday,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.initialTitle ?? '';

    // Seed options + checklist when editing an existing task
    if (widget.initialOptions != null) {
      _opts.value = widget.initialOptions!;
    }
    final initList = widget.initialChecklist ?? const <ChecklistEntry>[];
    for (final e in initList) {
      final item = _ChecklistItem(e.text)..done.value = e.done;
      _items.add(item);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autofocusTitle) _requestKeyboard();
    });
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    _titleCtrl.dispose();
    _titleFocus.dispose();
    _opts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final insets = mq.viewInsets; // keyboard
    final pad = mq.padding;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ===== Usable area above the keyboard + pinned footer =====
          Positioned.fill(
            bottom: insets.bottom + _kBarH,
            child: SafeArea(
              top: true,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, box) {
                  // Same centered caret placement as the event page.
                  final caretY = box.maxHeight * 0.20;
                  final contentTop = caretY + 110; // area where list starts

                  return Stack(
                    children: [
                      // Top-right Close / Delete row
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.showDelete)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                tooltip: 'Delete',
                                onPressed: widget.onDelete,
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              tooltip: 'Close',
                              onPressed: _close,
                            ),
                          ],
                        ),
                      ),

                      // Centered title caret
                      Positioned(
                        top: caretY,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _CenteredTitleField(
                              controller: _titleCtrl,
                              focusNode: _titleFocus,
                              onDone: _save,
                              autofocus: widget.autofocusTitle,
                            ),
                          ),
                        ),
                      ),

                      // Scrollable content below title
                      Positioned.fill(
                        top: contentTop,
                        child: ScrollConfiguration(
                          behavior: const _NoGlow(),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Add item pill
                                const _AddItemTile(),
                                const SizedBox(height: 12),

                                // Subtasks list (AnimatedList)
                                Offstage(
                                  offstage: _items.isEmpty,
                                  child: AnimatedList(
                                    key: _listKey,
                                    initialItemCount: _items.length,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemBuilder: (context, index, animation) {
                                      final item = _items[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: SizeTransition(
                                          sizeFactor: CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOut,
                                          ),
                                          child: Dismissible(
                                            key: item.key,
                                            direction:
                                                DismissDirection.horizontal,
                                            confirmDismiss: (direction) async {
                                              _removeItemAt(index);
                                              return false;
                                            },
                                            background: const SizedBox.shrink(),
                                            child: _ChecklistRow(
                                              controller: item.controller,
                                              focusNode: item.focusNode,
                                              doneListenable: item.done,
                                              onToggle: () =>
                                                  _toggleItem(index),
                                              onSubmitted: (last) {
                                                if (last) _addItem();
                                              },
                                              onDelete: () =>
                                                  _removeItemAt(index),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Date / Reminder / Deadline panel
                                TaskOptionsPanel(controller: _opts),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ===== Black footer pinned to the keyboard (Cancel / Done) =====
          Positioned(
            left: 0,
            right: 0,
            bottom: insets.bottom,
            child: Container(
              height: _kBarH + pad.bottom,
              color: Colors.black,
              padding: EdgeInsets.only(left: 16, right: 16, bottom: pad.bottom),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _save,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Centered title input =====
class _CenteredTitleField extends StatelessWidget {
  const _CenteredTitleField({
    required this.controller,
    required this.focusNode,
    required this.onDone,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onDone;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      textAlign: TextAlign.center,
      cursorColor: Colors.white,
      cursorWidth: 3,
      cursorHeight: 48,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 44,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
      decoration: const InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: '',
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onDone(),
      onEditingComplete: onDone,
      onTapOutside: (_) => focusNode.requestFocus(),
      // NOTE: not const — list contains non-const elements
      inputFormatters: [
        FilteringTextInputFormatter.singleLineFormatter,
        LengthLimitingTextInputFormatter(100),
      ],
    );
  }
}

// ===== Existing helpers (tweaked) =====

class _AddItemTile extends StatelessWidget {
  const _AddItemTile();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_TaskEditorPageState>()!;
    return _RoundedTile(
      height: 48,
      radius: 22,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => state._addItem(),
        child: Row(
          children: const [
            Icon(Icons.add_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            _AddItemLabel(),
          ],
        ),
      ),
    );
  }
}

class _AddItemLabel extends StatelessWidget {
  const _AddItemLabel();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Add item',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ChecklistItem {
  _ChecklistItem(String initial)
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

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
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
              // NOTE: not const — list contains non-const elements
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

class _RemovedChecklistRow extends StatelessWidget {
  const _RemovedChecklistRow({
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
class _NoGlow extends ScrollBehavior {
  const _NoGlow();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // no glow
  }
}

class _RoundedTile extends StatelessWidget {
  const _RoundedTile({required this.child, this.height = 56, this.radius = 28});
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
