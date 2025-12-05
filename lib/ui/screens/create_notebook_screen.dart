// lib/ui/screens/create_notebook_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        FilteringTextInputFormatter,
        LengthLimitingTextInputFormatter,
        SystemChannels;
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/project_provider.dart';
import 'package:kontinuum/models/project_model.dart';

const double _kBarH = 44;
const double _kCaretToGroupGap = 168; // distance from caret to options pill

class CreateNotebookResult {
  final String title;
  final String icon; // emoji or glyph
  final int color; // ARGB
  final String? projectId;
  final List<String> tags;
  final List<String> collaborators;
  final String? password; // null if none

  const CreateNotebookResult({
    required this.title,
    required this.icon,
    required this.color,
    required this.projectId,
    required this.tags,
    required this.collaborators,
    required this.password,
  });
}

class CreateNotebookScreen extends StatefulWidget {
  const CreateNotebookScreen({super.key, required this.heroTag});
  final String heroTag;

  @override
  State<CreateNotebookScreen> createState() => _CreateNotebookScreenState();
}

enum _OpenSection { none, icon, color, project, tags, collabs, password }

class _CreateNotebookScreenState extends State<CreateNotebookScreen> {
  // ---- Title ----
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();

  // ---- Options state ----
  String _icon = '📓';
  Color _color = const Color(0xFF6C8CFF);
  String? _projectId;
  List<String> _tags = <String>[];
  List<String> _collabs = <String>[];
  String?
      _password; // store plaintext for now (you can hash/store securely later)

  bool _closing = false;
  bool _popped = false;

  _OpenSection _open = _OpenSection.none;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = '';
    // Autofocus title after first frame (matches your editor UX)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _titleFocus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing || _popped) return;
    _closing = true;
    _popped = true;
    Navigator.of(context).maybePop();
  }

  void _done() {
    if (_closing || _popped) return;
    final title =
        _titleCtrl.text.trim().isEmpty ? 'Notebook' : _titleCtrl.text.trim();
    final res = CreateNotebookResult(
      title: title,
      icon: _icon,
      color: _color.value,
      projectId: _projectId,
      tags: List<String>.from(_tags),
      collaborators: List<String>.from(_collabs),
      password: _password,
    );
    _closing = true;
    _popped = true;
    Navigator.of(context).pop(res);
  }

  void _toggleSection(_OpenSection s) {
    FocusScope.of(context).unfocus();
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _open = (_open == s) ? _OpenSection.none : s;
      });
    });
  }

  bool _isOpen(_OpenSection s) => _open == s;

  String _projectName(List<Project> projects) {
    if (_projectId == null) return 'No Project';
    final idx = projects.indexWhere((p) => p.id == _projectId);
    if (idx == -1) return 'No Project';
    return projects[idx].name;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final insets = mq.viewInsets; // keyboard
    final pad = mq.padding;
    final projects = context.watch<ProjectProvider>().projects;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Full-screen hero so the tile expands into the whole screen.
          Positioned.fill(
            child: Hero(
              tag: widget.heroTag,
              child: const ColoredBox(color: Colors.black),
            ),
          ),

          // ---- area above keyboard + pinned footer ----
          Positioned.fill(
            bottom: insets.bottom + _kBarH,
            child: SafeArea(
              top: true,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, box) {
                  final caretY = box.maxHeight * 0.20;
                  final contentTop = caretY + _kCaretToGroupGap;

                  return Stack(
                    children: [
                      // Close (top-right)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 28),
                          tooltip: 'Close',
                          onPressed: _close,
                        ),
                      ),

                      // Centered title caret/field (no hint text)
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
                              onDone: _done,
                              autofocus: true,
                            ),
                          ),
                        ),
                      ),

                      // Scrollable content
                      Positioned.fill(
                        top: contentTop,
                        child: ScrollConfiguration(
                          behavior: const _NoGlowBehavior(),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                RoundedGroup(
                                  radius: 16,
                                  children: [
                                    // ===== ICON =====
                                    RowTile(
                                      title: 'Icon: $_icon',
                                      subtitle: 'Tap to choose',
                                      trailingIcon:
                                          Icons.emoji_emotions_rounded,
                                      onTap: () =>
                                          _toggleSection(_OpenSection.icon),
                                    ),
                                    _InlineDrop(
                                      expanded: _isOpen(_OpenSection.icon),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 0, 12, 12),
                                        child: _IconPickerInline(
                                          selected: _icon,
                                          onSelected: (emoji) {
                                            setState(() => _icon = emoji);
                                          },
                                        ),
                                      ),
                                    ),
                                    const DividerRow(),

                                    // ===== COLOR =====
                                    RowTile(
                                      title:
                                          'Color: #${_color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                                      subtitle: 'Tap to choose',
                                      trailingIcon: Icons.palette_rounded,
                                      onTap: () =>
                                          _toggleSection(_OpenSection.color),
                                    ),
                                    _InlineDrop(
                                      expanded: _isOpen(_OpenSection.color),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 0, 12, 12),
                                        child: _ColorPickerInline(
                                          selected: _color,
                                          onSelected: (c) {
                                            setState(() => _color = c);
                                          },
                                        ),
                                      ),
                                    ),
                                    const DividerRow(),

                                    // ===== PROJECT =====
                                    RowTile(
                                      title: _projectName(projects),
                                      subtitle: 'Project (optional)',
                                      trailingIcon: Icons.folder_open_rounded,
                                      onTap: () =>
                                          _toggleSection(_OpenSection.project),
                                    ),
                                    _InlineDrop(
                                      expanded: _isOpen(_OpenSection.project),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 4, right: 4, bottom: 10),
                                        child: _ProjectPickerInline(
                                          projects: projects,
                                          selectedId: _projectId,
                                          onSelected: (id) {
                                            setState(() => _projectId = id);
                                          },
                                        ),
                                      ),
                                    ),
                                    const DividerRow(),

                                    // ===== TAGS =====
                                    RowTile(
                                      title: _tags.isEmpty
                                          ? 'No Tags'
                                          : _tags.length == 1
                                              ? _tags.first
                                              : '${_tags.first} +${_tags.length - 1} more',
                                      subtitle: 'Tap to edit tags',
                                      trailingIcon: Icons.sell_rounded,
                                      onTap: () =>
                                          _toggleSection(_OpenSection.tags),
                                    ),
                                    _InlineDrop(
                                      expanded: _isOpen(_OpenSection.tags),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 0, 12, 12),
                                        child: _NotebookTagEditorInline(
                                          tags: _tags,
                                          onAddTag: (t) {
                                            setState(() {
                                              if (!_tags.contains(t)) {
                                                _tags.add(t);
                                              }
                                            });
                                          },
                                          onRemoveTag: (t) {
                                            setState(() {
                                              _tags.remove(t);
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const DividerRow(),

                                    // ===== COLLABORATORS =====
                                    RowTile(
                                      title: _collabs.isEmpty
                                          ? 'No Collaborators'
                                          : '${_collabs.length} collaborator${_collabs.length == 1 ? '' : 's'}',
                                      subtitle: 'Tap to invite or remove',
                                      trailingIcon: Icons.group_rounded,
                                      onTap: () =>
                                          _toggleSection(_OpenSection.collabs),
                                    ),
                                    _InlineDrop(
                                      expanded: _isOpen(_OpenSection.collabs),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 0, 12, 12),
                                        child:
                                            _NotebookCollaboratorEditorInline(
                                          people: _collabs,
                                          onAddPerson: (p) {
                                            setState(() {
                                              if (!_collabs.contains(p)) {
                                                _collabs.add(p);
                                              }
                                            });
                                          },
                                          onRemovePerson: (p) {
                                            setState(() {
                                              _collabs.remove(p);
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const DividerRow(),

                                    // ===== PASSWORD =====
                                    RowTile(
                                      title: _password == null
                                          ? 'No Password'
                                          : 'Passcode set',
                                      subtitle: _password == null
                                          ? 'Tap to add a passcode/biometric'
                                          : 'Tap to change or remove',
                                      trailingIcon: Icons.lock_rounded,
                                      onTap: () =>
                                          _toggleSection(_OpenSection.password),
                                    ),
                                    _InlineDrop(
                                      expanded: _isOpen(_OpenSection.password),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 0, 12, 12),
                                        child: _NotebookPasswordInline(
                                          current: _password,
                                          onChanged: (newPass) {
                                            setState(() {
                                              _password = newPass;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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

          // ---- Footer (Cancel / Done) ----
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
                    onTap: _done,
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

/* ───────────────────────── Helpers (local, same visual language) ───────────────────────── */

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
        // No hint text—keep the caret clean
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

class RoundedGroup extends StatelessWidget {
  const RoundedGroup({super.key, required this.children, this.radius = 16});
  final List<Widget> children;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(children: children),
    );
  }
}

class RowTile extends StatelessWidget {
  const RowTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.trailingIcon,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _TitleSubtitle(title: title, subtitle: subtitle),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(trailingIcon, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleSubtitle extends StatelessWidget {
  const _TitleSubtitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class DividerRow extends StatelessWidget {
  const DividerRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0x14FFFFFF),
      indent: 14,
      endIndent: 14,
    );
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

/// Smooth height+opacity expander (same pattern as Mission editor).
class _InlineDrop extends StatelessWidget {
  const _InlineDrop({required this.expanded, required this.child});
  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 240),
      crossFadeState:
          expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstCurve: Curves.easeInCubic,
      secondCurve: Curves.easeOutCubic,
      sizeCurve: Curves.easeOutCubic,
      firstChild: const SizedBox.shrink(),
      secondChild: child,
    );
  }
}

/* ───────────────────────── Inline Icon Picker ───────────────────────── */

class _IconPickerInline extends StatelessWidget {
  const _IconPickerInline({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static const _emojis = [
    '📓',
    '📒',
    '📘',
    '📙',
    '📔',
    '📗',
    '📕',
    '📚',
    '📝',
    '✍️',
    '📄',
    '📑',
    '🗒️',
    '🗂️',
    '🗃️',
    '🎤',
    '🎧',
    '🎵',
    '🎶',
    '🎛️',
    '🎼',
    '⭐',
    '🔥',
    '⚡',
    '🌙',
    '🌟',
    '💎',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Choose Icon',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: _emojis.length,
          itemBuilder: (_, i) {
            final emoji = _emojis[i];
            final isSelected = emoji == selected;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelected(emoji),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFF222831),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: 24,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/* ───────────────────────── Inline Color Picker ───────────────────────── */

class _ColorPickerInline extends StatelessWidget {
  const _ColorPickerInline({
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  static const _palette = [
    Color(0xFF6C8CFF),
    Color(0xFFFF6FD8),
    Color(0xFF9E7BFF),
    Color(0xFF21D07A),
    Color(0xFFFFB020),
    Color(0xFFFF4D4D),
    Color(0xFF00D3D3),
    Color(0xFF7ED957),
    Color(0xFFB084EB),
    Color(0xFF3AA2FF),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Choose Color',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in _palette)
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onSelected(c),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: c.value == selected.value
                          ? Colors.white
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/* ───────────────────────── Inline Project Picker ───────────────────────── */

class _ProjectPickerInline extends StatelessWidget {
  const _ProjectPickerInline({
    required this.projects,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Project> projects;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151515),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.block, color: Colors.white70),
            title: const Text(
              'None',
              style: TextStyle(color: Colors.white),
            ),
            trailing: selectedId == null
                ? const Icon(Icons.check, color: Colors.white)
                : null,
            onTap: () => onSelected(null),
          ),
          const Divider(color: Color(0x14FFFFFF), height: 1),
          if (projects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No projects yet',
                style: TextStyle(
                  color: Color(0x66FFFFFF),
                  fontSize: 13,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: projects.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Color(0x14FFFFFF), height: 1),
                itemBuilder: (_, i) {
                  final p = projects[i];
                  final selected = p.id == selectedId;
                  return ListTile(
                    leading: const Icon(Icons.folder, color: Colors.white70),
                    title: Text(
                      p.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () => onSelected(p.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/* ───────────────────────── Inline Tags Editor ───────────────────────── */

class _NotebookTagEditorInline extends StatefulWidget {
  const _NotebookTagEditorInline({
    required this.tags,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  final List<String> tags;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;

  @override
  State<_NotebookTagEditorInline> createState() =>
      _NotebookTagEditorInlineState();
}

class _NotebookTagEditorInlineState extends State<_NotebookTagEditorInline> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    widget.onAddTag(t);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF232323),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x22FFFFFF), width: 1),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: 'Add a tag',
                    hintStyle: TextStyle(color: Color(0x66FFFFFF)),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _add,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in widget.tags)
                _ChipPill(
                  label: t,
                  onRemove: () => widget.onRemoveTag(t),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────── Inline Collaborators Editor ───────────────────────── */

class _NotebookCollaboratorEditorInline extends StatefulWidget {
  const _NotebookCollaboratorEditorInline({
    required this.people,
    required this.onAddPerson,
    required this.onRemovePerson,
  });

  final List<String> people;
  final ValueChanged<String> onAddPerson;
  final ValueChanged<String> onRemovePerson;

  @override
  State<_NotebookCollaboratorEditorInline> createState() =>
      _NotebookCollaboratorEditorInlineState();
}

class _NotebookCollaboratorEditorInlineState
    extends State<_NotebookCollaboratorEditorInline> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    widget.onAddPerson(t);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF232323),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x22FFFFFF), width: 1),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: 'Add email or username',
                    hintStyle: TextStyle(color: Color(0x66FFFFFF)),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _add,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Invite'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in widget.people)
                _ChipPill(
                  label: p,
                  onRemove: () => widget.onRemovePerson(p),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────── Small bits ───────────────────────── */

class _ChipPill extends StatelessWidget {
  const _ChipPill({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(18),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── Inline Password Editor ───────────────────────── */

class _NotebookPasswordInline extends StatefulWidget {
  const _NotebookPasswordInline({
    required this.current,
    required this.onChanged,
  });

  final String? current;
  final ValueChanged<String?> onChanged;

  @override
  State<_NotebookPasswordInline> createState() =>
      _NotebookPasswordInlineState();
}

class _NotebookPasswordInlineState extends State<_NotebookPasswordInline> {
  final TextEditingController _ctrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final a = _ctrl.text;
    final b = _confirmCtrl.text;
    if (a.isEmpty && b.isEmpty) {
      widget.onChanged(null);
      _ctrl.clear();
      _confirmCtrl.clear();
      return;
    }
    if (a != b) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passcodes do not match')),
      );
      return;
    }
    widget.onChanged(a);
    _ctrl.clear();
    _confirmCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrent = widget.current != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PassField(label: 'Passcode', controller: _ctrl),
        const SizedBox(height: 10),
        _PassField(label: 'Confirm Passcode', controller: _confirmCtrl),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _save,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            if (hasCurrent) ...[
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    widget.onChanged(null);
                    _ctrl.clear();
                    _confirmCtrl.clear();
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0x33222222),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Remove',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PassField extends StatefulWidget {
  const _PassField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  State<_PassField> createState() => _PassFieldState();
}

class _PassFieldState extends State<_PassField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _obscure,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: widget.label,
                hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
              ),
            ),
          ),
          IconButton(
            splashRadius: 18,
            icon: Icon(
              _obscure
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ],
      ),
    );
  }
}
