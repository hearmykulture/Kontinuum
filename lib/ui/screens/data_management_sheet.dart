import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/data/reset_service.dart';
import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/providers/fitness_profile_provider.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/providers/project_provider.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/services/backup/data_backup_service.dart';
import 'package:kontinuum/services/backup/local_file_backup_transport.dart';
import 'package:kontinuum/services/backup/provider_refresh_service.dart';

class DataManagementSheet extends StatefulWidget {
  const DataManagementSheet({
    super.key,
    required this.backupService,
    this.resetService = const ResetService(),
  });

  final DataBackupService backupService;
  final ResetService resetService;

  @override
  State<DataManagementSheet> createState() => _DataManagementSheetState();
}

class _DataManagementSheetState extends State<DataManagementSheet> {
  bool _busy = false;
  String? _status;
  String? _error;
  String? _progressStage;
  BackupImportPreview? _preview;
  Uint8List? _previewBytes;
  bool _confirmOverwrite = false;
  BackupCancellationToken? _token;
  final ProviderRefreshService _providerRefreshService =
      const ProviderRefreshService();

  final _transport = LocalFileBackupTransport();

  Future<void> _runAsync(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progressStage = null;
    });
    _token = BackupCancellationToken();
    try {
      await fn();
    } on BackupUserCancelled {
      // no-op
    } on BackupCancelledException {
      setState(() {
        _status = 'Operation cancelled';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progressStage = null;
        });
      }
      _token = null;
    }
  }

  Future<void> _export() async {
    await _runAsync(() async {
      await widget.backupService.exportAndSave(
        transport: _transport,
        cancellationToken: _token,
        onProgress: (stage) => setState(() {
          _progressStage = 'Exporting $stage...';
        }),
      );
      setState(() {
        _status = 'Backup saved.';
      });
    });
  }

  Future<void> _chooseImport() async {
    await _runAsync(() async {
      Uint8List bytes;
      try {
        bytes = await _transport.load();
      } on BackupUserCancelled {
        return; // silent cancel
      }
      final preview = await widget.backupService.dryRunTransform(bytes);
      setState(() {
        _preview = preview;
        _previewBytes = bytes;
        _confirmOverwrite = false;
        _status = 'Preview ready. Review and confirm import.';
      });
    });
  }

  Future<void> _importConfirmed() async {
    final bytes = _previewBytes;
    if (bytes == null) return;
    await _runAsync(() async {
      final objectiveProvider = context.read<ObjectiveProvider>();
      final missionProvider = context.read<MissionProvider>();
      final workoutProvider = context.read<WorkoutProvider>();
      final dietProvider = context.read<DietProvider>();
      final fitnessProvider = context.read<FitnessProfileProvider>();
      final budgetProvider = context.read<BudgetProvider>();

      await widget.backupService.importFromBytes(
        bytes,
        cancellationToken: _token,
        onProgress: (stage) => setState(() {
          _progressStage = 'Importing $stage...';
        }),
        objectiveProvider: objectiveProvider,
        missionProvider: missionProvider,
        workoutProvider: workoutProvider,
        dietProvider: dietProvider,
        fitnessProfileProvider: fitnessProvider,
        budgetProvider: budgetProvider,
      );
      setState(() {
        _status = 'Backup restored.';
      });
    });
  }

  Future<void> _reset() async {
    await _runAsync(() async {
      await widget.resetService.clearAllData();
      final objectiveProvider = context.read<ObjectiveProvider>();
      final missionProvider = context.read<MissionProvider>();
      final workoutProvider = context.read<WorkoutProvider>();
      final dietProvider = context.read<DietProvider>();
      final fitnessProvider = context.read<FitnessProfileProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final projectProvider = context.read<ProjectProvider>();

      await _providerRefreshService.refresh(
        objectiveProvider: objectiveProvider,
        missionProvider: missionProvider,
        workoutProvider: workoutProvider,
        dietProvider: dietProvider,
        fitnessProfileProvider: fitnessProvider,
        budgetProvider: budgetProvider,
        projectProvider: projectProvider,
      );

      setState(() {
        _status = 'All data cleared.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Data management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Export includes all modules (progress, missions, workouts, budgets, diet, streaks, banking data). Keep backups private.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Save backup'),
                onPressed: _busy ? null : _export,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload),
                label: Text(_previewBytes == null
                    ? 'Load backup'
                    : 'Confirm load'),
                onPressed:
                    _busy ? null : (_previewBytes == null ? _chooseImport : _importConfirmed),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text('Factory reset'),
                onPressed: _busy ? null : _reset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_preview != null) _buildPreviewSummary(),
          if (_previewBytes != null) ...[
            if ((_preview?.missingAdapterTypeIds.isNotEmpty ?? false) ||
                (_preview?.hasErrors ?? false))
              const Text(
                'Fix errors above before importing.',
                style: TextStyle(color: Colors.redAccent),
              ),
            CheckboxListTile(
              value: _confirmOverwrite,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _confirmOverwrite = v ?? false),
              title: const Text('I understand this will overwrite all data.'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Confirm load'),
              onPressed: _busy ||
                      !_confirmOverwrite ||
                      (_preview?.hasErrors ?? false) ||
                      (_preview?.missingAdapterTypeIds.isNotEmpty ?? false)
                  ? null
                  : _importConfirmed,
            ),
          ],
          if (_busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_progressStage ?? 'Working...'),
          ],
          if (_token != null && _busy)
            TextButton(
              onPressed: () => _token?.cancel(),
              child: const Text('Cancel'),
            ),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(
              _status!,
              style: const TextStyle(color: Colors.greenAccent),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewSummary() {
    final preview = _preview;
    if (preview == null) return const SizedBox.shrink();
    final manifest = preview.manifest;
    final missingAdapters = preview.missingAdapterTypeIds;
    final counts = <String>[
      for (final entry in manifest.sections.entries)
        if (entry.value.counts.isNotEmpty)
          '${entry.key}: ${entry.value.counts.values.fold<int>(0, (a, b) => a + b)}'
    ].join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Preview: schema ${manifest.schemaVersion}, modules ${manifest.moduleVersions}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (counts.isNotEmpty) Text('Totals: $counts'),
        if (preview.messages.isNotEmpty)
          ...preview.messages.map(
            (m) => Text(
              '[${m.severity.name}] ${m.message}',
              style: TextStyle(
                color: m.severity == BackupValidationSeverity.error
                    ? Colors.redAccent
                    : Colors.orangeAccent,
              ),
            ),
          ),
        if (missingAdapters.isNotEmpty)
          Text(
            'Missing adapters: ${missingAdapters.join(', ')}',
            style: const TextStyle(color: Colors.redAccent),
          ),
      ],
    );
  }
}
