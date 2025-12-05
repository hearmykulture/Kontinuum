import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/exercise_library_service.dart';
import 'package:kontinuum/ui/common/safe_network_image.dart';
import 'package:kontinuum/ui/theme/app_colors.dart';
import 'package:kontinuum/utils/text_format.dart';

import 'widgets/exercise_category_bar.dart';
import 'widgets/exercise_insights.dart';
import 'widgets/exercise_list.dart';
import 'widgets/exercise_search_bar.dart';

const List<String> _kCategories = <String>[
  'ALL',
  'Chest',
  'Back',
  'Shoulders',
  'Arms',
  'Core',
  'Glutes',
  'Quads',
  'Hamstrings',
];

const Map<String, List<String>> _kCategoryAliases = <String, List<String>>{
  'Chest': <String>[
    'chest',
    'pecs',
    'pectorals',
    'upper chest',
    'lower chest',
  ],
  'Back': <String>[
    'back',
    'upper back',
    'mid back',
    'lower back',
    'lats',
    'latissimus dorsi',
    'traps',
  ],
  'Shoulders': <String>[
    'shoulders',
    'delts',
    'front delts',
    'rear delts',
    'side delts',
  ],
  'Arms': <String>[
    'arms',
    'biceps',
    'triceps',
    'forearms',
  ],
  'Core': <String>[
    'core',
    'abs',
    'abdominals',
    'obliques',
  ],
  'Glutes': <String>[
    'glutes',
    'gluteus maximus',
    'gluteus medius',
    'gluteus minimus',
    'hip flexors',
  ],
  'Quads': <String>[
    'quads',
    'quadriceps',
    'vastus lateralis',
    'vastus medialis',
    'vastus intermedius',
    'rectus femoris',
  ],
  'Hamstrings': <String>[
    'hamstrings',
    'posterior chain',
    'biceps femoris',
    'semitendinosus',
    'semimembranosus',
    'calves',
    'gastrocnemius',
    'soleus',
  ],
};

class AddExercisePopup extends StatefulWidget {
  const AddExercisePopup({
    super.key,
    this.heroTag,
    this.headerLabel = 'Add exercise',
    this.initialExerciseId,
    this.detailsMode = false,
  });

  final String? heroTag;
  final String headerLabel;
  final String? initialExerciseId;
  final bool detailsMode;

  @override
  State<AddExercisePopup> createState() => _AddExercisePopupState();
}

class _AddExercisePopupState extends State<AddExercisePopup> {
  final ExerciseLibraryService _library = ExerciseLibraryService.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _listFocus = FocusNode(skipTraversal: true);
  final ScrollController _categoryScroll = ScrollController();
  final PageController _pageController = PageController();
  final PageController _previewController = PageController();
  final Map<int, ScrollController> _listControllers = <int, ScrollController>{};
  final Map<int, int> _highlightedByCategory = <int, int>{};
  final Map<int, List<Exercise>> _filteredByCategory = <int, List<Exercise>>{};
  final List<GlobalKey> _categoryKeys =
      List<GlobalKey>.generate(_kCategories.length, (_) => GlobalKey());

  Timer? _debounce;
  Exercise? _selectedExercise;
  int _selectedCategoryIndex = 0;
  int _highlightedIndex = -1;
  int _previewPage = 0;
  final Set<String> _selectedExerciseIds = <String>{};
  final List<String> _selectionOrder = <String>[];

  bool get _isDetailsMode => widget.detailsMode;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _kCategories.length; i++) {
      _listControllers[i] = ScrollController();
      _highlightedByCategory[i] = -1;
    }

    if (_isDetailsMode) {
      final String? initialId = widget.initialExerciseId;
      if (initialId != null && initialId.isNotEmpty) {
        _selectedExercise = _library.getById(initialId);
        _precachePreview(_selectedExercise);
      }
    } else {
      _refreshAfterQuery();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerCategory(_selectedCategoryIndex);
        final String? initialId = widget.initialExerciseId;
        if (initialId != null && initialId.isNotEmpty) {
          _selectExerciseById(initialId);
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _listFocus.dispose();
    _categoryScroll.dispose();
    _pageController.dispose();
    _previewController.dispose();
    for (final controller in _listControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final double viewInsets = media.viewInsets.bottom;
    final bool keyboardVisible = viewInsets > 0.0;
    final double constrainedHeight =
        math.min(size.height - viewInsets - 24, 820);

    final Widget content = _isDetailsMode
        ? _buildDetailsContent(context, constrainedHeight)
        : _buildSelectionContent(context, constrainedHeight);

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(
          24,
          keyboardVisible ? 12 : 24,
          24,
          keyboardVisible ? 12 : 24,
        ),
        child: Align(
          alignment: keyboardVisible ? Alignment.topCenter : Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton(
    BuildContext context, {
    bool overlay = false,
  }) {
    final closeLabel = MaterialLocalizations.of(context).closeButtonLabel;

    // Unified black "X" (no circular background), slightly smaller on overlay.
    final double iconSize = overlay ? 22 : 24;
    final double splashRadius = overlay ? 20 : 22;

    final iconButton = IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(
        Icons.close_rounded,
        color: Colors.black,
      ),
      tooltip: closeLabel,
      iconSize: iconSize,
      splashRadius: splashRadius,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 44,
        minHeight: 44,
      ),
    );

    // No extra circle/DecoratedBox for overlay anymore.
    return iconButton;
  }

  /// Header now only shows the close "X" in the top-right.
  Widget _buildHeader(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: _buildCloseButton(context),
    );
  }

  Widget _buildMediaPreview(Exercise? exercise) {
    final String? url = exercise?.mediaUrl?.trim();
    final bool hasMedia = url != null && url.isNotEmpty;

    return Container(
      // pure white behind the GIF
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: hasMedia
            ? ExercisePreviewImage(
                key: ValueKey(url),
                url: url,
              )
            : const ExercisePreviewPlaceholder(
                key: ValueKey('media-placeholder'),
              ),
      ),
    );
  }

  Widget _buildMuscleChartPreview(
    Exercise? exercise,
    Map<String, double> coverage,
  ) {
    final bool hasSelection = exercise != null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: hasSelection
            ? ExerciseRadar(
                key: ValueKey(exercise.id),
                coverage: coverage,
                accentColor: AppColors.accentBlue,
              )
            : const ExerciseChartPlaceholder(
                key: ValueKey('no-coverage'),
                icon: Icons.show_chart_outlined,
                message: 'Select an exercise to view coverage',
              ),
      ),
    );
  }

  Widget _buildInstructionPreview(Exercise? exercise) {
    final List<String> steps = exercise == null
        ? const <String>[]
        : _parseInstructionSteps(exercise.instructions);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: ExerciseInstructionSlide(
          key: ValueKey(exercise?.id ?? 'no-instructions'),
          steps: steps.isEmpty
              ? const <String>['No instructions provided.']
              : steps,
        ),
      ),
    );
  }

  /// Enlarged & shifted preview: taller slides so the GIF is clearer,
  /// and the dots sit closer to the search bar.
  Widget _buildPreview({Widget? overlay}) {
    final Exercise? exercise = _selectedExercise;
    final Map<String, double> coverage = computeExerciseCoverage(exercise);

    final List<Widget> slides = [
      _buildMediaPreview(exercise),
      _buildMuscleChartPreview(exercise, coverage),
      _buildInstructionPreview(exercise),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        // Make the preview area larger, scaling with width.
        final double computedHeight = width * 0.7;
        final double previewHeight =
            computedHeight.clamp(220.0, 360.0).toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: previewHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView(
                      controller: _previewController,
                      physics: const ClampingScrollPhysics(),
                      onPageChanged: (index) {
                        if (_previewPage == index) return;
                        setState(() => _previewPage = index);
                      },
                      children: slides,
                    ),
                    if (overlay != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: SafeArea(
                          minimum: const EdgeInsets.all(12),
                          child: overlay,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (index) {
                final bool isActive = index == _previewPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 12 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.accentBlue
                        : AppColors.accentBlue.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectionContent(
    BuildContext context,
    double constrainedHeight,
  ) {
    return FocusScope(
      autofocus: true,
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.escape):
              const _DismissIntent(),
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              const _FocusSearchIntent(),
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              const _FocusSearchIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              const _MoveSelectionIntent.down(),
          const SingleActivator(LogicalKeyboardKey.arrowUp):
              const _MoveSelectionIntent.up(),
          const SingleActivator(LogicalKeyboardKey.enter):
              const _SelectHighlightedIntent(),
          const SingleActivator(LogicalKeyboardKey.numpadEnter):
              const _SelectHighlightedIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
              onInvoke: (intent) {
                _searchFocus.requestFocus();
                _searchCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _searchCtrl.text.length,
                );
                return null;
              },
            ),
            _DismissIntent: CallbackAction<_DismissIntent>(
              onInvoke: (intent) {
                Navigator.of(context).maybePop();
                return null;
              },
            ),
            _MoveSelectionIntent: CallbackAction<_MoveSelectionIntent>(
              onInvoke: (intent) {
                _moveHighlight(intent.delta);
                return null;
              },
            ),
            _SelectHighlightedIntent: CallbackAction<_SelectHighlightedIntent>(
              onInvoke: (intent) {
                _selectHighlighted();
                return null;
              },
            ),
          },
          child: _buildCard(
            constrainedHeight: constrainedHeight,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildPreview(
                      overlay: _buildCloseButton(
                        context,
                        overlay: true,
                      ),
                    ),
                    // Smaller spacer so dots sit just above the search bar.
                    const SizedBox(height: 12),
                    ExerciseSearchBar(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      autofocus: true,
                      hintText: 'Search exercises…',
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) => _listFocus.requestFocus(),
                      onCleared: () => _onSearchChanged(''),
                    ),
                    const SizedBox(height: 6),
                    ExerciseCategoryBar(
                      categories: _kCategories,
                      selectedIndex: _selectedCategoryIndex,
                      scrollController: _categoryScroll,
                      itemKeys: _categoryKeys,
                      onSelected: _handleCategoryTap,
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Focus(
                        focusNode: _listFocus,
                        canRequestFocus: true,
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const ClampingScrollPhysics(),
                          onPageChanged: (index) => _handleCategorySwipe(index),
                          itemCount: _kCategories.length,
                          itemBuilder: (context, index) {
                            final exercises = _getFiltered(index);
                            final bool isActive =
                                index == _selectedCategoryIndex;
                            final int highlighted = isActive
                                ? _highlightedIndex
                                : _highlightedByCategory[index] ?? -1;

                            if (exercises.isEmpty) {
                              return _EmptyLibraryState(
                                query: _searchCtrl.text.trim(),
                                category: _kCategories[index],
                              );
                            }

                            return RawScrollbar(
                              controller: _listControllers[index],
                              radius: const Radius.circular(12),
                              thickness: 4,
                              thumbColor:
                                  Colors.black.withValues(alpha: 0.12),
                              child: Padding(
                                // breathing room only when the button is visible
                                padding: EdgeInsets.only(
                                  bottom:
                                      _selectedExerciseIds.isNotEmpty ? 72 : 4,
                                ),
                                child: ExerciseList(
                                  exercises: exercises,
                                  controller: _listControllers[index]!,
                                  highlightedIndex: highlighted,
                                  selectedIds: _selectedExerciseIds,
                                  enableInteractions: isActive,
                                  onHighlight: isActive
                                      ? _handleExerciseHighlighted
                                      : null,
                                  onToggleSelect: isActive
                                      ? _toggleExerciseSelection
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    children: [
                      AnimatedOpacity(
                        opacity: _selectedExerciseIds.isNotEmpty ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: IgnorePointer(
                          ignoring: true,
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildCompleteButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required double constrainedHeight,
    required Widget child,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: constrainedHeight,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDetailsContent(
    BuildContext context,
    double constrainedHeight,
  ) {
    final Exercise? exercise = _selectedExercise;

    return _buildCard(
      constrainedHeight: constrainedHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: exercise == null
                  ? _buildMissingExercisePlaceholder()
                  : _buildExerciseDetails(exercise),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingExercisePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        Icon(Icons.error_outline, size: 42, color: Colors.black38),
        SizedBox(height: 12),
        Text(
          'Exercise data unavailable',
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          'Try again later or pick a different exercise.',
          style: TextStyle(
            color: Colors.black45,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildExerciseDetails(Exercise exercise) {
    const Color textPrimary = Color(0xFF1F2A37);
    const Color textSecondary = Color(0xFF4C566A);

    final String? mediaUrl = exercise.mediaUrl?.trim();
    final bool hasMedia = mediaUrl != null && mediaUrl.isNotEmpty;
    final Map<String, double> coverage = computeExerciseCoverage(exercise);
    final bool hasCoverage = coverage.values.any((double value) => value > 0.0);

    final List<String> muscleTags = _buildMuscleTags(exercise);
    final List<String> equipmentTags = _buildEquipmentTags(exercise);
    final List<String> instructionSteps =
        _parseInstructionSteps(exercise.instructions);
    final List<String> cues = exercise.cues
        .map((cue) => cue.trim())
        .where((cue) => cue.isNotEmpty)
        .map(formatTitleCase)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: hasMedia
                  ? ExercisePreviewImage(url: mediaUrl)
                  : const ExercisePreviewPlaceholder(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          formatTitleCase(exercise.name),
          style: const TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        if (muscleTags.isNotEmpty || equipmentTags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in muscleTags)
                _detailTagChip(tag, Icons.fitness_center, textSecondary),
              for (final tag in equipmentTags)
                _detailTagChip(tag, Icons.handyman_outlined, textSecondary),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.black.withValues(alpha: 0.04)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailMetaRow(
                'Difficulty',
                _formatTag(exercise.difficulty.name),
                textPrimary,
                textSecondary,
              ),
              const SizedBox(height: 10),
              _detailMetaRow(
                'Intent',
                _formatTag(exercise.intent.name),
                textPrimary,
                textSecondary,
              ),
              if (exercise.attribution != null &&
                  exercise.attribution!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _detailMetaRow(
                  'Attribution',
                  exercise.attribution!.trim(),
                  textPrimary,
                  textSecondary,
                  wrapValue: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (cues.isNotEmpty) ...[
          _detailSectionTitle('Coaching cues', textPrimary),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cues.map(_detailCueChip).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (hasCoverage) ...[
          _detailSectionTitle('Muscle coverage', textPrimary),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: SizedBox(
              height: 160,
              child: ExerciseRadar(
                coverage: coverage,
                accentColor: AppColors.accentBlue,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _detailSectionTitle('Instructions', textPrimary),
        const SizedBox(height: 10),
        _buildInstructionList(instructionSteps, textPrimary, textSecondary),
      ],
    );
  }

  Widget _buildInstructionList(
    List<String> steps,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (steps.isEmpty) {
      return Text(
        'No instructions provided.',
        style: TextStyle(
          color: textSecondary.withValues(alpha: 0.7),
          fontSize: 13.5,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}.',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  steps[i],
                  style: TextStyle(
                    color: textSecondary.withValues(alpha: 0.9),
                    fontSize: 13.2,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          if (i != steps.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _detailTagChip(
    String label,
    IconData icon,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCueChip(String cue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accentBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_outlined,
            size: 14,
            color: AppColors.accentBlue.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            cue,
            style: TextStyle(
              color: AppColors.accentBlue.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailMetaRow(
    String label,
    String value,
    Color textPrimary,
    Color textSecondary, {
    bool wrapValue = false,
  }) {
    return Row(
      crossAxisAlignment:
          wrapValue ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: textPrimary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: textSecondary.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.35,
            ),
            softWrap: wrapValue,
            maxLines: wrapValue ? null : 1,
            overflow: wrapValue ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _detailSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    );
  }

  Widget _buildCompleteButton() {
    final bool enabled = _selectedExerciseIds.isNotEmpty;
    final ButtonStyle style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      backgroundColor: enabled
          ? AppColors.accentBlue
          : AppColors.accentBlue.withValues(alpha: 0.4),
      foregroundColor: Colors.white,
    );
    final String label =
        enabled ? 'Complete (${_selectedExerciseIds.length})' : 'Complete';

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(top: 4),
      child: Center(
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: !enabled,
            child: FilledButton(
              onPressed: enabled ? _completeSelection : null,
              style: style,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _refreshAfterQuery(maintainSelection: true);
    });
  }

  void _handleCategoryTap(int index) {
    if (_selectedCategoryIndex == index) return;
    _handleCategoryChange(index, fromSwipe: false);
  }

  void _handleCategorySwipe(int index) {
    _handleCategoryChange(index, fromSwipe: true);
  }

  void _handleCategoryChange(int index, {required bool fromSwipe}) {
    final List<Exercise> list = _getFiltered(index);
    int nextIndex = _highlightedByCategory[index] ?? 0;
    if (list.isEmpty) {
      nextIndex = -1;
    } else if (nextIndex < 0 || nextIndex >= list.length) {
      nextIndex = 0;
    }

    setState(() {
      _selectedCategoryIndex = index;
      _highlightedIndex = nextIndex;
      if (nextIndex >= 0) {
        _selectedExercise = list[nextIndex];
        _highlightedByCategory[index] = nextIndex;
      } else {
        _selectedExercise = null;
        _highlightedByCategory[index] = -1;
      }
      _previewPage = 0;
    });

    _schedulePreviewPagerJump();
    _precachePreview(_selectedExercise);
    _centerCategory(index);
    if (!fromSwipe) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    _scheduleListScroll();
  }

  void _handleExerciseHighlighted(int index) {
    final List<Exercise> list = _getFiltered(_selectedCategoryIndex);
    if (index < 0 || index >= list.length) return;
    if (_highlightedIndex == index) return;

    setState(() {
      _highlightedIndex = index;
      _highlightedByCategory[_selectedCategoryIndex] = index;
      _selectedExercise = list[index];
      _previewPage = 0;
    });
    _schedulePreviewPagerJump();
    _precachePreview(_selectedExercise);
  }

  void _toggleExerciseSelection(Exercise exercise) {
    final bool wasSelected = _selectedExerciseIds.contains(exercise.id);
    setState(() {
      if (wasSelected) {
        _selectedExerciseIds.remove(exercise.id);
        _selectionOrder.remove(exercise.id);
      } else {
        _selectedExerciseIds.add(exercise.id);
        _selectionOrder.remove(exercise.id);
        _selectionOrder.add(exercise.id);
      }
      _selectedExercise = exercise;
      _previewPage = 0;
    });
    _schedulePreviewPagerJump();
    _precachePreview(_selectedExercise);
  }

  void _completeSelection() {
    if (_selectedExerciseIds.isEmpty) return;
    final List<Exercise> selected = _selectionOrder
        .map((id) => _library.getById(id))
        .whereType<Exercise>()
        .toList(growable: false);
    if (selected.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }

    for (final exercise in selected) {
      _library.recordRecent(exercise.id);
    }
    Navigator.of(context).pop(selected);
  }

  void _refreshAfterQuery({bool maintainSelection = false}) {
    final String? previousId = maintainSelection ? _selectedExercise?.id : null;
    late final List<Exercise> currentList;

    setState(() {
      _filteredByCategory.clear();
      currentList = _getFiltered(_selectedCategoryIndex);
      if (currentList.isEmpty) {
        _highlightedIndex = -1;
        _selectedExercise = null;
        _highlightedByCategory[_selectedCategoryIndex] = -1;
        _previewPage = 0;
      } else {
        int nextIndex = 0;
        if (previousId != null) {
          nextIndex = currentList.indexWhere((ex) => ex.id == previousId);
        } else {
          nextIndex = _highlightedByCategory[_selectedCategoryIndex] ?? 0;
        }
        if (nextIndex < 0 || nextIndex >= currentList.length) {
          nextIndex = 0;
        }
        _highlightedIndex = nextIndex;
        _highlightedByCategory[_selectedCategoryIndex] = nextIndex;
        _selectedExercise = currentList[nextIndex];
        _previewPage = 0;
      }
    });

    _precachePreview(_selectedExercise);
    _schedulePreviewPagerJump();
    _scheduleListScroll(animate: false);
  }

  List<Exercise> _getFiltered(int categoryIndex) {
    return _filteredByCategory.putIfAbsent(categoryIndex, () {
      final String category = _kCategories[categoryIndex];
      final String query = _searchCtrl.text.trim();
      final List<String> muscles = _aliasesForCategory(category);
      return _library.filter(
        muscles: muscles.isEmpty ? null : muscles,
        query: query.isEmpty ? null : query,
      );
    });
  }

  List<String> _aliasesForCategory(String category) {
    if (category == 'ALL') return const <String>[];
    return _kCategoryAliases[category] ??
        <String>[category.toLowerCase().trim()];
  }

  void _precachePreview(Exercise? exercise) {
    final String? url = exercise?.mediaUrl;
    if (url == null || url.trim().isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        safePrecacheNetworkImage(
          context,
          url,
          cacheWidth: 96,
          cacheHeight: 96,
        ),
      );
    });
  }

  void _centerCategory(int index) {
    final BuildContext? ctx = _categoryKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _schedulePreviewPagerJump({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_previewController.hasClients) return;
      if (animate) {
        _previewController.animateToPage(
          _previewPage,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _previewController.jumpToPage(_previewPage);
      }
    });
  }

  void _scheduleListScroll({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollListToHighlighted(animate: animate);
    });
  }

  void _scrollListToHighlighted({bool animate = true}) {
    if (_highlightedIndex < 0) return;
    final ScrollController? controller =
        _listControllers[_selectedCategoryIndex];
    if (controller == null || !controller.hasClients) return;
    final double target =
        math.max(0, (_highlightedIndex * ExerciseList.itemExtent) - 40);
    final double clamped =
        target.clamp(0.0, controller.position.maxScrollExtent);
    if (animate) {
      controller.animateTo(
        clamped,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      controller.jumpTo(clamped);
    }
  }

  void _moveHighlight(int delta) {
    final List<Exercise> list = _getFiltered(_selectedCategoryIndex);
    if (list.isEmpty) return;
    final int nextIndex = (_highlightedIndex + delta).clamp(0, list.length - 1);
    if (nextIndex == _highlightedIndex) return;

    setState(() {
      _highlightedIndex = nextIndex;
      _highlightedByCategory[_selectedCategoryIndex] = nextIndex;
      _selectedExercise = list[nextIndex];
      _previewPage = 0;
    });
    _precachePreview(_selectedExercise);
    _schedulePreviewPagerJump();
    _scheduleListScroll();
  }

  void _selectHighlighted() {
    final List<Exercise> list = _getFiltered(_selectedCategoryIndex);
    if (_highlightedIndex < 0 || _highlightedIndex >= list.length) return;
    _toggleExerciseSelection(list[_highlightedIndex]);
  }

  void _selectExerciseById(String id) {
    final List<Exercise> allExercises = _getFiltered(0);
    final int index = allExercises.indexWhere((ex) => ex.id == id);
    if (index == -1) return;

    setState(() {
      _selectedCategoryIndex = 0;
      _highlightedIndex = index;
      _highlightedByCategory[_selectedCategoryIndex] = index;
      _selectedExercise = allExercises[index];
      _previewPage = 0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(_selectedCategoryIndex);
    }

    _schedulePreviewPagerJump();
    _precachePreview(_selectedExercise);
    _centerCategory(_selectedCategoryIndex);
    _scheduleListScroll(animate: false);
  }

  List<String> _buildMuscleTags(Exercise exercise) {
    final Set<String> tags = <String>{
      ...exercise.muscles,
      ...exercise.primaryMuscles,
      ...exercise.secondaryMuscles,
    };
    final List<String> formatted = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .map(_formatTag)
        .toSet()
        .toList();
    formatted.sort();
    return formatted;
  }

  List<String> _buildEquipmentTags(Exercise exercise) {
    final List<String> formatted = exercise.equipment
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .map(_formatTag)
        .toSet()
        .toList();
    formatted.sort();
    return formatted;
  }

  String _formatTag(String input) => formatTitleCase(input);

  List<String> _parseInstructionSteps(String raw) {
    if (raw.trim().isEmpty) return const <String>[];
    return raw
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(
          (line) => line
              .replaceFirst(
                RegExp(
                  r'^(?:step\s*[:\-]?)?\s*\d+[.:)\-\s]*',
                  caseSensitive: false,
                ),
                '',
              )
              .replaceFirst(RegExp(r'^[-•]\s*'), '')
              .trim(),
        )
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState({
    required this.query,
    required this.category,
  });

  final String query;
  final String category;

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = query.isNotEmpty;
    final String message = hasQuery
        ? 'No exercises match “$query”.'
        : 'No exercises found for $category.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: Colors.black.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (hasQuery) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Try a different name or category.',
              style: TextStyle(
                color: Colors.black45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

class _MoveSelectionIntent extends Intent {
  const _MoveSelectionIntent(this.delta);

  final int delta;

  const _MoveSelectionIntent.down() : delta = 1;
  const _MoveSelectionIntent.up() : delta = -1;
}

class _SelectHighlightedIntent extends Intent {
  const _SelectHighlightedIntent();
}
