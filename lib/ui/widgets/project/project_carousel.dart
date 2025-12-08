// lib/ui/widgets/project/project_carousel.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/project_model.dart';
import 'package:kontinuum/providers/project_provider.dart';
import 'package:kontinuum/ui/screens/project_screen.dart' as screens;

/// Scrollable horizontal grid of project cards with hero animations and
/// trailing create button.
class ProjectCarousel extends StatefulWidget {
  const ProjectCarousel({
    super.key,
    required this.twoRows,
    this.cardColor = const Color(0xFF0A0E11),
    this.padding,
    this.columns = 4, // used when fixedItemSize is null
    this.fixedItemSize, // hard-lock square tile width/height if provided
  });

  final bool twoRows;
  final Color cardColor;

  /// Optional external padding (horizontal is respected; vertical is merged
  /// with internal top/bottom + scrollbar gutter).
  final EdgeInsetsGeometry? padding;

  /// Target number of columns to fit when computing dynamic size.
  final int columns;

  /// If set, each square tile will be exactly this size.
  final double? fixedItemSize;

  @override
  State<ProjectCarousel> createState() => _ProjectCarouselState();
}

class _ProjectCarouselState extends State<ProjectCarousel> {
  static const double _hPad = 16;
  static const double _spacing = 12;
  static const double _topBottomPad = 12;
  static const double _scrollbarGutter = 10; // reserves space for bottom bar

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectProvider>().projects;
    final rows = widget.twoRows ? 2 : 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;

        // Horizontal padding to apply (merge user padding if provided)
        final EdgeInsets resolvedPad = () {
          final base =
              widget.padding ?? const EdgeInsets.symmetric(horizontal: _hPad);
          final b = base.resolve(Directionality.of(context));
          return EdgeInsets.fromLTRB(
            b.left,
            (b.top == 0 ? _topBottomPad : b.top),
            b.right,
            (b.bottom == 0 ? _topBottomPad : b.bottom) + _scrollbarGutter,
          );
        }();

        // Compute tile size.
        final int cols = widget.fixedItemSize == null
            ? widget.columns.clamp(1, 12)
            : ((maxW - (resolvedPad.left + resolvedPad.right) + _spacing) /
                    ((widget.fixedItemSize!) + _spacing))
                .floor()
                .clamp(1, 12);

        final double computedItemSize = widget.fixedItemSize ??
            ((maxW -
                    (resolvedPad.left + resolvedPad.right) -
                    (_spacing * (cols - 1))) /
                cols);

        // Cross-axis content height that produces square tiles.
        final double contentHeight =
            (computedItemSize * rows) + (_spacing * (rows - 1));

        // Container height includes top/bottom + reserved gutter,
        // but tiles only see `contentHeight` thanks to padding above.
        final double containerHeight =
            contentHeight + (_topBottomPad * 2) + _scrollbarGutter;

        final totalTiles = projects.length + 1;

        final grid = GridView.builder(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          padding: resolvedPad,
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: rows,
            mainAxisSpacing: _spacing, // horizontal spacing
            crossAxisSpacing: _spacing, // vertical spacing
            // Pin per-tile width along the scroll direction so 4 fit exactly
            // (or whatever `columns` computes to). This eliminates size drift.
            mainAxisExtent: computedItemSize,
          ),
          itemCount: totalTiles,
          itemBuilder: (context, index) {
            if (index < projects.length) {
              final Project p = projects[index];
              return _ProjectCard(
                size: computedItemSize,
                project: p,
                cardColor: widget.cardColor,
              );
            }
            return _CreateTile(
              size: computedItemSize,
              cardColor: widget.cardColor,
            );
          },
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: containerHeight,
              child: Scrollbar(
                controller: _scrollCtrl,
                thumbVisibility: true,
                trackVisibility: false,
                interactive: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                radius: const Radius.circular(8),
                thickness: 4,
                child: grid,
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x1FFFFFFF)),
          ],
        );
      },
    );
  }
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.size, required this.cardColor});
  final double size;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'create_project_card',
      flightShuttleBuilder: heroZoomShuttle,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                transitionDuration: const Duration(milliseconds: 420),
                reverseTransitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (_, __, ___) => const screens.ProjectScreen(
                  projectId: null,
                  heroTag: 'create_project_card',
                ),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(
                  opacity: CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutCubic,
                  ),
                  child: child,
                ),
              ),
            );
          },
          // Centered plus + centered label, keeping the icon size consistent
          // with project tiles to avoid any size regression.
          child: const _CreateCenteredBody(),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.size,
    required this.project,
    required this.cardColor,
  });
  final double size;
  final Project project;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    final tag = 'project_card_${project.id}';

    return Hero(
      tag: tag,
      flightShuttleBuilder: heroZoomShuttle,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                transitionDuration: const Duration(milliseconds: 420),
                reverseTransitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (_, __, ___) =>
                    screens.ProjectScreen(projectId: project.id, heroTag: tag),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(
                  opacity: CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutCubic,
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: _CardBody(
            title: project.name,
            subtitle:
                '${project.tracks.length} track${project.tracks.length == 1 ? '' : 's'}',
            icon: Icons.folder,
          ),
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    this.title,
    this.subtitle,
    this.icon,
  });

  final String? title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, left: 8),
                child:
                    Icon(icon ?? Icons.folder, color: Colors.white70, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (title != null)
            Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            )
          else
            const Text(
              'Create',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _CreateCenteredBody extends StatelessWidget {
  const _CreateCenteredBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, color: Colors.white70, size: 22),
          SizedBox(height: 8),
          Text('Create', style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Reusable zoom shuttle shared by project carousel hero flights.
Widget heroZoomShuttle(
  BuildContext context,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromCtx,
  BuildContext toCtx,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final begin = direction == HeroFlightDirection.push ? 1.0 : 1.04;
  final end = direction == HeroFlightDirection.push ? 1.04 : 1.0;
  return ScaleTransition(
    scale: Tween<double>(begin: begin, end: end).animate(curved),
    child: Material(
      type: MaterialType.transparency,
      child: (direction == HeroFlightDirection.push
          ? fromCtx.widget
          : toCtx.widget),
    ),
  );
}
