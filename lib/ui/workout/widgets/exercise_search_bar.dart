import 'package:flutter/material.dart';

class ExerciseSearchBar extends StatefulWidget {
  const ExerciseSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onCleared,
    this.onSubmitted,
    this.autofocus = false,
    this.hintText = 'Search…',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final String hintText;

  @override
  State<ExerciseSearchBar> createState() => _ExerciseSearchBarState();
}

class _ExerciseSearchBarState extends State<ExerciseSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant ExerciseSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool hasText = widget.controller.text.trim().isNotEmpty;

    return SizedBox(
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFDADADA)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(width: 10),
            const Icon(
              Icons.search_rounded,
              color: Colors.black54,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                autofocus: widget.autofocus,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  border: InputBorder.none,
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasText)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 16),
                color: Colors.black45,
                tooltip: 'Clear search',
                splashRadius: 16,
                padding: EdgeInsets.zero,
                onPressed: () {
                  widget.controller.clear();
                  widget.onCleared();
                  widget.focusNode.requestFocus();
                },
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
