import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/mission.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/data/stat_repository.dart';

class MissionBankScreen extends StatelessWidget {
  const MissionBankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Mission Bank',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFF6C63FF),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Completed'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Add mission',
              icon: const Icon(Icons.add),
              onPressed: () async {
                final created = await showDialog<Mission>(
                  context: context,
                  builder: (_) => const _NewMissionDialog(),
                );
                if (created != null && context.mounted) {
                  context.read<MissionProvider>().addMission(created);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mission added')),
                  );
                }
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [_AllMissionsTab(), _CompletedMissionsTab()],
        ),
      ),
    );
  }
}

// --------------------------- All missions ---------------------------

class _AllMissionsTab extends StatelessWidget {
  const _AllMissionsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<MissionProvider>(
      builder: (ctx, provider, _) {
        final items = provider.allMissionsSorted;
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No missions in the bank yet.',
              style: TextStyle(color: Colors.white60),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.white10),
          itemBuilder: (_, i) {
            final m = items[i];
            final color = _rarityColor(m.rarity);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                m.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(
                      m.rarity.name.toUpperCase(),
                      border: color,
                      text: color,
                    ),
                    _chip(
                      '${m.xpReward} XP',
                      border: Colors.cyanAccent,
                      text: Colors.cyanAccent,
                    ),
                    if (m.categoryIds.isNotEmpty)
                      _chip(
                        m.categoryIds.first.toUpperCase(),
                        border: Colors.white24,
                        text: Colors.white70,
                      ),
                    if (m.isCompleted)
                      _chip(
                        'COMPLETED',
                        border: Colors.greenAccent,
                        text: Colors.greenAccent,
                      ),
                    if (m.isAccepted)
                      _chip(
                        'ACCEPTED',
                        border: Colors.amberAccent,
                        text: Colors.amberAccent,
                      ),
                  ],
                ),
              ),
              trailing: Wrap(
                spacing: 6,
                children: [
                  IconButton(
                    tooltip: 'Put on board',
                    icon: const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      final ok = provider.putOnBoard(m.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? 'Added to board' : 'Could not add to board',
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => provider.deleteMission(m.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _rarityColor(MissionRarity r) => switch (r) {
    MissionRarity.common => Colors.grey,
    MissionRarity.rare => Colors.cyanAccent,
    MissionRarity.legendary => Colors.deepPurpleAccent,
  };

  Widget _chip(String label, {required Color border, required Color text}) {
    Color alpha(Color c, double o) => c.withAlpha((o * 255).round());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alpha(border, 0.6)),
        color: alpha(border, 0.09),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ------------------------- Completed missions -------------------------

class _CompletedMissionsTab extends StatelessWidget {
  const _CompletedMissionsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MissionProvider>();
    final completed = provider.completedMissions;

    if (completed.isEmpty) {
      return const Center(
        child: Text(
          'Nothing completed yet.',
          style: TextStyle(color: Colors.white60),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: completed.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Colors.white10),
      itemBuilder: (_, i) {
        final m = completed[i];
        final color = switch (m.rarity) {
          MissionRarity.common => Colors.grey,
          MissionRarity.rare => Colors.cyanAccent,
          MissionRarity.legendary => Colors.deepPurpleAccent,
        };

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            m.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(m.rarity.name.toUpperCase(), border: color, text: color),
                _chip(
                  '${m.xpReward} XP',
                  border: Colors.cyanAccent,
                  text: Colors.cyanAccent,
                ),
                if (m.categoryIds.isNotEmpty)
                  _chip(
                    m.categoryIds.first.toUpperCase(),
                    border: Colors.white24,
                    text: Colors.white70,
                  ),
              ],
            ),
          ),
          trailing: Wrap(
            spacing: 6,
            children: [
              IconButton(
                tooltip: 'Reopen',
                icon: const Icon(Icons.undo, color: Colors.cyanAccent),
                onPressed: () {
                  provider.markIncomplete(m);
                  provider.putOnBoard(m.id);
                },
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => provider.deleteMission(m.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, {required Color border, required Color text}) {
    Color alpha(Color c, double o) => c.withAlpha((o * 255).round());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alpha(border, 0.6)),
        color: alpha(border, 0.09),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ------------------------- New mission dialog -------------------------

class _NewMissionDialog extends StatefulWidget {
  const _NewMissionDialog();

  @override
  State<_NewMissionDialog> createState() => _NewMissionDialogState();
}

class _NewMissionDialogState extends State<_NewMissionDialog> {
  final _titleCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _xpCtrl = TextEditingController(text: '100');

  String? _categoryId;
  String? _statId;
  MissionRarity _rarity = MissionRarity.common;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _idCtrl.dispose();
    _descCtrl.dispose();
    _xpCtrl.dispose();
    super.dispose();
  }

  String _toIdSlug(String s) {
    final x = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return x.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  }

  bool _validMeta(dynamic m) {
    final id = (m.id ?? '').toString().trim();
    final display = (m.display ?? '').toString().trim();
    final cat = (m.categoryId ?? '').toString().trim();
    return id.isNotEmpty && display.isNotEmpty && cat.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final missionProvider = context.read<MissionProvider>();
    final objectiveProvider = context.read<ObjectiveProvider>();

    final categories = objectiveProvider.categories.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final statMetas = StatRepository.getAll().where(_validMeta).toList()
      ..sort((a, b) => a.display.toString().compareTo(b.display.toString()));

    final previewId = (_idCtrl.text.isEmpty
        ? _toIdSlug(_titleCtrl.text)
        : _idCtrl.text);

    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B23),
      title: const Text('New Mission', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'Write 10 metaphors or punchlines',
                hintStyle: TextStyle(color: Colors.white38),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFF0D1116),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _idCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'ID (optional)',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: previewId,
                hintStyle: const TextStyle(color: Colors.white38),
                border: const OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: const Color(0xFF0D1116),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFF0D1116),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _categoryId,
              dropdownColor: const Color(0xFF23232B),
              style: const TextStyle(color: Colors.white),
              items: categories
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
              decoration: const InputDecoration(
                labelText: 'Category',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFF0D1116),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _statId,
              dropdownColor: const Color(0xFF23232B),
              style: const TextStyle(color: Colors.white),
              items: statMetas
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.id.toString(),
                      child: Text(m.display.toString()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _statId = v),
              decoration: const InputDecoration(
                labelText: 'Stat',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFF0D1116),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _xpCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'XP Reward',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFF0D1116),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<MissionRarity>(
              value: _rarity,
              dropdownColor: const Color(0xFF23232B),
              style: const TextStyle(color: Colors.white),
              items: MissionRarity.values
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        r.name[0].toUpperCase() + r.name.substring(1),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _rarity = v ?? _rarity),
              decoration: const InputDecoration(
                labelText: 'Rarity',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFF0D1116),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Final ID: ${previewId.isEmpty ? '—' : previewId}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleCtrl.text.trim();
            final id = (_idCtrl.text.trim().isEmpty)
                ? _toIdSlug(title)
                : _idCtrl.text.trim();
            final xp = int.tryParse(_xpCtrl.text.trim()) ?? 0;

            if (title.isEmpty ||
                id.isEmpty ||
                xp <= 0 ||
                _categoryId == null ||
                _statId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Fill title, ID, category, stat and positive XP.',
                  ),
                ),
              );
              return;
            }

            // Prevent duplicate IDs
            final exists = missionProvider.allMissionsSorted.any(
              (m) => m.id.toLowerCase() == id.toLowerCase(),
            );
            if (exists) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ID already exists. Pick another.'),
                ),
              );
              return;
            }

            final mission = Mission(
              id: id,
              title: title,
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              categoryIds: [_categoryId!],
              statIds: [_statId!],
              xpReward: xp,
              rarity: _rarity,
              isAccepted: false,
              isCompleted: false,
            );

            Navigator.pop(context, mission);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
