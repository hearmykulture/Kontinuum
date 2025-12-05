import 'package:flutter/material.dart';

class DietLibraryScreen extends StatelessWidget {
  const DietLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: pull from Hive
    final items = const [
      _Food('Protein shake', 220),
      _Food('Oatmeal + PB', 410),
      _Food('Salmon + rice + veg', 620),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final f = items[index];
        return ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: Colors.white,
          title: Text(f.name),
          subtitle: Text('${f.kcal} kcal'),
          trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: open "add to meal" sheet
            },
          ),
        );
      },
    );
  }
}

class _Food {
  final String name;
  final int kcal;
  const _Food(this.name, this.kcal);
}
