// lib/ui/screens/task_editor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kontinuum/ui/widgets/corner_icons.dart';
import 'task_editor/models.dart';
import 'task_editor/checklist.dart';
import 'task_editor/panels_and_calendar.dart';

const double _kBarH = 44;

/// Full-screen “Create Task” / “View Task” page (styled to match Add Event).
class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({
    super.key,
    this.initialTitle,
    this.autofocusTitle = true,
    this.showDelete = false,
    this.onDelete,
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
  final List<ChecklistItemModel> _items = <ChecklistItemModel>[];

  void _addItem([String initial = '']) {
    final wasEmpty = _items.isEmpty;
    final index = _items.length;
    final item = ChecklistItemModel(initial);
    _items.insert(index, item);
    _listKey.currentState
        ?.insertItem(index, duration: const Duration(milliseconds: 220));
    if (wasEmpty) setState(() {}); // only rebuild when empty->nonempty
    WidgetsBinding.instance
        .addPostFrameCallback((_) => item.focusNode.requestFocus());
  }

  void _toggleItem(int i) {
    if (i < 0 || i >= _items.length) return;
    _items[i].done.value = !_items[i].done.value; // row listens
  }

  void _removeItemAt(int index) {
    if (index < 0 || index >= _items.length) return;
    final willBeEmpty = _items.length == 1;
    final removed = _items.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => RemovedChecklistRow(
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

    final title =
        _titleCtrl.text.trim().isEmpty ? 'Task' : _titleCtrl.text.trim();
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
        deadline: v.deadline,
        someday: v.someday,
        // ✅ keep all selected stats
        stats: List<StatPick>.from(v.stats),
        // legacy mirrors for any older code paths
        statId: v.statId,
        statAmount: v.statAmount,
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
      final item = ChecklistItemModel(e.text)..done.value = e.done;
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
                      // Corner icons (delete + close)
                      CornerIcons(
                        top: 0,
                        leftIcon:
                            widget.showDelete ? Icons.delete_outline : null,
                        onLeftPressed:
                            widget.showDelete ? widget.onDelete : null,
                        leftTooltip: 'Delete',
                        rightIcon: Icons.close,
                        onRightPressed: _close,
                        rightTooltip: 'Close',
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
                          behavior: const NoGlowScrollBehavior(),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Add item pill
                                AddItemTile(onAdd: _addItem),
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
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
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
                                            child: ChecklistRow(
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

                                // Date / Reminder / Deadline / Stat panel
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
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
      inputFormatters: [
        FilteringTextInputFormatter.singleLineFormatter,
        LengthLimitingTextInputFormatter(100),
      ],
    );
  }
}
