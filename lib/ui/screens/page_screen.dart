import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

enum NotebookPageStyle { note, journal, list, lyric }

class PageScreen extends StatefulWidget {
  const PageScreen({
    super.key,
    required this.notebookId,
  });

  final String notebookId;

  static const Color bg = Color(0xFF0F151A);

  @override
  State<PageScreen> createState() => _PageScreenState();
}

class _PageScreenState extends State<PageScreen> {
  NotebookPageStyle? _style;

  @override
  void initState() {
    super.initState();
    // Show style chooser after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialStyleChooser();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _showInitialStyleChooser() async {
    if (!mounted || _style != null) return;

    final chosen = await _showStyleDialog(
      barrierDismissible: false, // Must choose or back out
    );

    if (!mounted) return;

    if (chosen == null) {
      // User backed out via system back; just close this screen.
      Navigator.of(context).maybePop();
      return;
    }

    setState(() => _style = chosen);
  }

  Future<void> _changeStyle() async {
    final chosen = await _showStyleDialog(
      barrierDismissible: true,
    );
    if (!mounted || chosen == null) return;
    setState(() => _style = chosen);
  }

  Future<NotebookPageStyle?> _showStyleDialog({
    required bool barrierDismissible,
  }) {
    return showDialog<NotebookPageStyle>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151515),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Choose page style',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StyleOption(
                icon: Icons.description_rounded,
                label: 'Note',
                description: 'Simple, free-form text editor.',
                onTap: () => Navigator.of(ctx).pop(NotebookPageStyle.note),
              ),
              const SizedBox(height: 8),
              _StyleOption(
                icon: Icons.menu_book_rounded,
                label: 'Journal',
                description: 'Guided prompts and reflection.',
                onTap: () => Navigator.of(ctx).pop(NotebookPageStyle.journal),
              ),
              const SizedBox(height: 8),
              _StyleOption(
                icon: Icons.checklist_rounded,
                label: 'List',
                description: 'Task-style bullet list.',
                onTap: () => Navigator.of(ctx).pop(NotebookPageStyle.list),
              ),
              const SizedBox(height: 8),
              _StyleOption(
                icon: Icons.music_note_rounded,
                label: 'Lyric',
                description: 'Lyric-focused writing tools.',
                onTap: () => Navigator.of(ctx).pop(NotebookPageStyle.lyric),
              ),
            ],
          ),
          actions: [
            if (barrierDismissible)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
          ],
        );
      },
    );
  }

  String _titleForStyle(NotebookPageStyle? style) {
    switch (style) {
      case NotebookPageStyle.note:
        return 'Note';
      case NotebookPageStyle.journal:
        return 'Journal';
      case NotebookPageStyle.list:
        return 'List';
      case NotebookPageStyle.lyric:
        return 'Lyric';
      case null:
        return 'Page';
    }
  }

  Widget _buildBody() {
    if (_style == null) {
      // While the dialog is up, just keep an empty body.
      return const SafeArea(
        child: SizedBox.shrink(),
      );
    }

    switch (_style!) {
      case NotebookPageStyle.note:
        return const _NoteEditor();
      case NotebookPageStyle.journal:
        return const _ComingSoonEditor(
          label: 'Journal style coming soon',
          description:
              'Here we\'ll add prompt-based journaling with a prompt bank.',
        );
      case NotebookPageStyle.list:
        return const _ComingSoonEditor(
          label: 'List style coming soon',
          description:
              'Here we\'ll add checklist-style items like an actions app.',
        );
      case NotebookPageStyle.lyric:
        return const _ComingSoonEditor(
          label: 'Lyric editor coming soon',
          description:
              'Here we\'ll plug in the full lyric editor / writing studio.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _titleForStyle(_style);

    return Scaffold(
      backgroundColor: PageScreen.bg,
      appBar: AppBar(
        backgroundColor: PageScreen.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Change style',
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
            onPressed: _changeStyle,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}

/* ───────────────────────── Style chooser tile ───────────────────────── */

class _StyleOption extends StatelessWidget {
  const _StyleOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────── Quill-powered Note Editor ───────────────────────── */

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({super.key});

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final quill.QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController.basic();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyHeader(int? level) {
    if (level == null) {
      _controller.formatSelection(quill.Attribute.header);
      return;
    }
    switch (level) {
      case 1:
        _controller.formatSelection(quill.Attribute.h1);
        break;
      case 2:
        _controller.formatSelection(quill.Attribute.h2);
        break;
      case 3:
        _controller.formatSelection(quill.Attribute.h3);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double inset = MediaQuery.of(context).viewInsets.bottom;
    final bool keyboardVisible = inset > 0;
    final double spacer = keyboardVisible ? 96 : 24;

    return SafeArea(
      top: true,
      bottom: false,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12171D),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Undo',
                        icon:
                            const Icon(Icons.undo_rounded, color: Colors.white),
                        onPressed: _controller.undo,
                        splashRadius: 22,
                      ),
                      IconButton(
                        tooltip: 'Redo',
                        icon:
                            const Icon(Icons.redo_rounded, color: Colors.white),
                        onPressed: _controller.redo,
                        splashRadius: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final attrs =
                                _controller.getSelectionStyle().attributes;
                            final headerAttr =
                                attrs[quill.Attribute.header.key];
                            final int? level = headerAttr?.value is int
                                ? headerAttr!.value as int
                                : null;

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _StyleChip(
                                    label: 'Normal',
                                    selected: level == null,
                                    onTap: () => _applyHeader(null),
                                  ),
                                  _StyleChip(
                                    label: 'Title',
                                    selected: level == 1,
                                    onTap: () => _applyHeader(1),
                                  ),
                                  _StyleChip(
                                    label: 'Heading',
                                    selected: level == 2,
                                    onTap: () => _applyHeader(2),
                                  ),
                                  _StyleChip(
                                    label: 'Subtitle',
                                    selected: level == 3,
                                    onTap: () => _applyHeader(3),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: quill.QuillEditor.basic(
                    controller: _controller,
                    config: const quill.QuillEditorConfig(
                      autoFocus: true,
                      expands: true,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacer),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _KeyboardAccessoryToolbar(
              controller: _controller,
              visible: keyboardVisible,
              keyboardInset: inset,
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFF20262D),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyboardAccessoryToolbar extends StatelessWidget {
  const _KeyboardAccessoryToolbar({
    required this.controller,
    required this.visible,
    required this.keyboardInset,
  });

  final quill.QuillController controller;
  final bool visible;
  final double keyboardInset;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(999);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 0.2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          opacity: visible ? 1 : 0,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: keyboardInset + 12,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: quill.QuillSimpleToolbar(
                      controller: controller,
                      config: quill.QuillSimpleToolbarConfig(
                        axis: Axis.horizontal,
                        multiRowsDisplay: false,
                        toolbarSectionSpacing: 10,
                        toolbarIconAlignment: WrapAlignment.start,
                        showDividers: false,
                        showFontFamily: true,
                        showFontSize: true,
                        showBoldButton: true,
                        showItalicButton: true,
                        showUnderLineButton: true,
                        showStrikeThrough: true,
                        showColorButton: false,
                        showBackgroundColorButton: false,
                        showClearFormat: false,
                        showAlignmentButtons: true,
                        showListBullets: true,
                        showListNumbers: true,
                        showListCheck: true,
                        showIndent: true,
                        showUndo: false,
                        showRedo: false,
                        showHeaderStyle: false,
                        showInlineCode: false,
                        showQuote: false,
                        showCodeBlock: false,
                        showLink: false,
                        showSearchButton: false,
                        toolbarSize: 38,
                        buttonOptions: quill.QuillSimpleToolbarButtonOptions(
                          base: quill.QuillToolbarBaseButtonOptions(
                            iconSize: 18,
                            iconButtonFactor: 1.0,
                            iconTheme: quill.QuillIconTheme(
                              iconButtonUnselectedData: quill.IconButtonData(
                                color: Colors.black87,
                                style: ButtonStyle(
                                  backgroundColor:
                                      MaterialStateProperty.all<Color>(
                                          Colors.transparent),
                                  overlayColor:
                                      MaterialStateProperty.all<Color>(
                                          Colors.black.withValues(alpha: 0.06)),
                                  shape: MaterialStateProperty.all<
                                      OutlinedBorder>(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              iconButtonSelectedData: quill.IconButtonData(
                                color: Colors.white,
                                style: ButtonStyle(
                                  backgroundColor:
                                      MaterialStateProperty.all<Color>(
                                          PageScreen.bg),
                                  shape: MaterialStateProperty.all<
                                      OutlinedBorder>(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── Coming Soon Placeholder ───────────────────────── */

class _ComingSoonEditor extends StatelessWidget {
  const _ComingSoonEditor({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── Scroll Behavior (unused for now but kept) ───────────────────────── */

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
