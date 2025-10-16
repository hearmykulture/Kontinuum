import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' show basename;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'block_text_editor.dart';
import 'audio/beat_bottom_player.dart';

class WritingEditorScreen extends StatefulWidget {
  const WritingEditorScreen({super.key});

  @override
  State<WritingEditorScreen> createState() => _WritingEditorScreenState();
}

class _WritingEditorScreenState extends State<WritingEditorScreen> {
  final AudioPlayer _player = AudioPlayer();

  String? _currentBeatName;
  String? _currentBeatPath; // drives waveform widget

  bool _isPicking = false;
  DateTime _lastPickTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<int> get _sdkInt async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 33;
    }
  }

  void _setBeatPath(String? path, {String? name}) {
    if (_currentBeatPath == path &&
        (name == null || _currentBeatName == name)) {
      debugPrint('↔️ Beat unchanged, skipping setState.');
      return;
    }
    setState(() {
      if (name != null) _currentBeatName = name;
      _currentBeatPath = path;
    });
    debugPrint('🎯 _currentBeatPath set to: $_currentBeatPath');
    if (_currentBeatPath != null) {
      debugPrint('🧭 bottom bar will mount with path: $_currentBeatPath');
    } else {
      debugPrint('🧭 bottom bar hidden (no filesystem path → no waveform)');
    }
  }

  Future<void> _loadBeat() async {
    // debounce
    final now = DateTime.now();
    if (now.difference(_lastPickTap).inMilliseconds < 400) return;
    _lastPickTap = now;

    if (_isPicking) return;
    if (mounted) setState(() => _isPicking = true);

    try {
      try {
        await FilePicker.platform.clearTemporaryFiles();
      } catch (_) {}

      // Android permissions
      var status = PermissionStatus.granted;
      if (Platform.isAndroid) {
        try {
          final sdk = await _sdkInt;
          status = sdk >= 33
              ? await Permission.audio.request()
              : await Permission.storage.request();
        } catch (e) {
          debugPrint('⚠️ Permission check failed: $e');
        }
      }
      if (!status.isGranted) {
        debugPrint('❌ Permission denied');
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3',
          'wav',
          'aiff',
          'm4a',
          'flac',
          'ogg',
          'aac',
          'caf',
        ],
        allowMultiple: false,
        withData: true, // get bytes so we can write a temp file
      );
      if (result == null || result.files.isEmpty) {
        debugPrint('🚫 User canceled picker');
        return;
      }

      final file = result.files.single;
      debugPrint(
        '📄 Pick result: name=${file.name}, path=${file.path}, '
        'id=${file.identifier}, bytes=${file.bytes?.length ?? 0}',
      );

      // Display name early
      String displayName = file.name;
      if (displayName.isEmpty && file.path != null) {
        displayName = basename(file.path!);
      }

      String? resolvedPath;

      // Prefer BYTES → write temp → we always get a real path (great for waveform)
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final tempPath =
            '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        await File(tempPath).writeAsBytes(file.bytes!, flush: true);
        debugPrint('🛠️ wrote temp file for waveform: $tempPath');
        resolvedPath = tempPath;

        // 🔑 set path immediately so BottomBeatPlayer mounts & starts extraction
        if (mounted) _setBeatPath(resolvedPath, name: displayName);

        // then prep audio
        try {
          await _player.stop();
        } catch (_) {}
        await _player.setFilePath(tempPath);
        await _player.play();
      } else if (file.path != null && File(file.path!).existsSync()) {
        debugPrint('📟 using file.path directly: ${file.path!}');
        resolvedPath = file.path!;

        // 🔑 set path immediately so BottomBeatPlayer mounts & starts extraction
        if (mounted) _setBeatPath(resolvedPath, name: displayName);

        try {
          await _player.stop();
        } catch (_) {}
        await _player.setFilePath(resolvedPath);
        await _player.play();
      } else if ((file.identifier ?? '').startsWith('content://')) {
        // Android SAF content URI only → can play, but no waveform path
        debugPrint('🔗 content URI only (no bytes/path): ${file.identifier}');
        try {
          await _player.stop();
        } catch (_) {}
        await _player.setUrl(file.identifier!);
        await _player.play();

        // Keep waveform hidden since there is no real file path
        if (mounted) _setBeatPath(null, name: displayName);
      } else {
        debugPrint('❌ Could not resolve audio source.');
        return;
      }
    } on PlatformException catch (e) {
      if (e.code == 'multiple_request') {
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        debugPrint('❌ PlatformException: $e');
      }
    } catch (e, st) {
      debugPrint('❌ Error loading beat: $e\n$st');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // Editor content
      body: SafeArea(
        bottom: false, // don't reserve space for the bottom bar
        child: BlockTextEditor(
          onLoadBeat: _loadBeat,
          isLoadingBeat: _isPicking,
        ),
      ),

      // Docked waveform bar (connected to the bottom)
      bottomNavigationBar: (_currentBeatPath == null)
          ? null
          : MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: BottomBeatPlayer(
                  player: _player,
                  filePath: _currentBeatPath,

                  // make it big
                  height: 120,

                  // bars look + gradient
                  style: WaveformStyle.bars,
                  useGradient: true,
                  barWidth: 4,
                  barGap: 2,
                  barRadius: 2,

                  // zoom + follow the playhead
                  viewSeconds: 12, // how many seconds are visible
                  followPlayhead: true, // auto-scroll viewport
                  lockPlayheadCenter:
                      true, // keep playhead centered when possible
                  extractPixelsPerSecond: 200, // crisp at this zoom
                ),
              ),
            ),
    );
  }
}
