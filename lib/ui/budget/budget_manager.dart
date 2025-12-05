// lib/ui/screens/budget/budget_manager.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/ui/screens/budget/budget_overview_screen.dart';
import 'package:kontinuum/ui/screens/budget/create_budget_screen.dart';

class BudgetManager extends StatefulWidget {
  const BudgetManager({super.key});

  // Match your budget palette
  static const Color kBg = Color(0xFF051F20);
  static const Color kCard = Color(0xFF0B2B26);
  static const Color kMint = Color(0xFFDAF1DE);

  @override
  State<BudgetManager> createState() => _BudgetManagerState();
}

class _BudgetManagerState extends State<BudgetManager> {
  bool _twoRows = false; // false = 4x1, true = 4x2

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BudgetManager.kBg,
      appBar: AppBar(
        backgroundColor: BudgetManager.kBg,
        elevation: 0,
        title: const Text('Budgets', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: _twoRows ? 'Switch to 4×1' : 'Switch to 4×2',
            icon: Icon(_twoRows ? Icons.view_stream : Icons.grid_view,
                color: Colors.white),
            onPressed: () => setState(() => _twoRows = !_twoRows),
          ),
        ],
      ),
      body: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final twoRows =
        context.findAncestorStateOfType<_BudgetManagerState>()?._twoRows ??
            false;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BudgetsHeader(twoRows: twoRows),
          const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: _PlaceholderBody(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetsHeader extends StatefulWidget {
  const _BudgetsHeader({required this.twoRows});
  final bool twoRows;

  @override
  State<_BudgetsHeader> createState() => _BudgetsHeaderState();
}

class _BudgetsHeaderState extends State<_BudgetsHeader> {
  static const double _hPad = 16;
  static const double _spacing = 12;

  final ScrollController _scrollCtrl = ScrollController();
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgets = context.watch<BudgetProvider>().budgets;
    final media = MediaQuery.of(context);
    final width = media.size.width;

    // Exactly 4 tiles visible across the viewport.
    final itemSize = (width - (_hPad * 2) - (_spacing * (4 - 1))) / 4.0;
    final rows = widget.twoRows ? 2 : 1;
    final gridHeight = (itemSize * rows) + (_spacing * (rows - 1));

    // Show scrollbar when overflow.
    final int totalTiles = budgets.length + 1; // +1 for Create tile
    final int visibleCapacity = 4 * rows;
    final bool showScrollbar = totalTiles > visibleCapacity;

    final grid = GridView.builder(
      controller: _scrollCtrl,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 12),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: rows, // rows; scroll horizontally
        mainAxisSpacing: _spacing,
        crossAxisSpacing: _spacing,
        childAspectRatio: 1.0, // square tiles
      ),
      itemCount: budgets.length + 1,
      itemBuilder: (context, index) {
        if (index < budgets.length) {
          final b = budgets[index];
          return _BudgetCardSmall(
            size: itemSize,
            title: b.title,
            monthly: _currency.format(b.monthlyAmount),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BudgetOverviewScreen(budgetId: b.id),
              ),
            ),
          );
        }
        return _CreateBudgetTileSmall(
          size: itemSize,
          onTap: () async {
            final prov = context.read<BudgetProvider>();
            if (prov.atCap) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Budget limit reached')),
              );
              return;
            }
            await Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => Scaffold(
                  backgroundColor: BudgetManager.kCard,
                  appBar: AppBar(
                    backgroundColor: BudgetManager.kCard,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                    title: const Text('Create Budget',
                        style: TextStyle(color: Colors.white)),
                  ),
                  body: SafeArea(
                    child: CreateBudgetScreen(
                      onClose: () => Navigator.of(context).maybePop(),
                      initial: null,
                      onComplete: (draft) {
                        prov.createBudget(draft);
                        Navigator.of(context).maybePop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Budget created')),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return SizedBox(
      height: gridHeight + 24,
      child: Scrollbar(
        controller: _scrollCtrl,
        thumbVisibility: showScrollbar,
        trackVisibility: showScrollbar,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        radius: const Radius.circular(8),
        thickness: 4,
        child: grid,
      ),
    );
  }
}

class _BudgetCardSmall extends StatelessWidget {
  const _BudgetCardSmall({
    required this.size,
    required this.title,
    required this.monthly,
    required this.onTap,
  });

  final double size;
  final String title;
  final String monthly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget roundedSquareIcon(IconData icon) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: BudgetManager.kMint.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: BudgetManager.kMint),
      );
    }

    return Material(
      color: BudgetManager.kCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: roundedSquareIcon(Icons.folder_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                Text('Monthly',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    )),
                Text(monthly,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BudgetManager.kMint.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateBudgetTileSmall extends StatelessWidget {
  const _CreateBudgetTileSmall({required this.size, required this.onTap});
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BudgetManager.kCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rounded square icon
                // (kept small to match the budget tiles)
                // The text remains two lines when narrow.
                // See roundedSquarePlus above.
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderBody extends StatelessWidget {
  const _PlaceholderBody();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topLeft,
      child:
          Text('(Content below the header…) ', style: TextStyle(color: Colors.white54)),
    );
  }
}
