import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:kontinuum/services/backup/backup_transport.dart';

class BackupUserCancelled implements Exception {}

/// Transport that uses `file_picker` to read/write backup bytes to a user-chosen
/// local path.
class LocalFileBackupTransport implements BackupTransport {
  static const defaultFileName = 'kontinuum-backup.json';

  LocalFileBackupTransport({FilePicker? picker})
      : _picker = picker ?? FilePicker.platform;

  final FilePicker _picker;
  String? lastSavedPath;

  @override
  String get label => 'Local file';

  @override
  Future<void> save(Uint8List bytes, {String? suggestedFileName}) async {
    final fileName = suggestedFileName ?? defaultFileName;

    // On mobile, use the picker with inline bytes so the user can choose a
    // visible location in Files.
    if (Platform.isAndroid || Platform.isIOS) {
      final path = await _picker.saveFile(
        dialogTitle: 'Save Kontinuum backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
        lockParentWindow: true,
      );
      if (path == null || path.isEmpty) {
        throw BackupUserCancelled();
      }
      lastSavedPath = path;
      return;
    }

    // Desktop: let the user pick a path, then write bytes.
    final path = await _picker.saveFile(
      dialogTitle: 'Save Kontinuum backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      lockParentWindow: true,
    );
    if (path == null || path.isEmpty) {
      throw BackupUserCancelled();
    }
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    lastSavedPath = file.path;
  }

  @override
  Future<Uint8List> load() async {
    String? initialDir;
    if (!Platform.isAndroid && !Platform.isIOS && lastSavedPath != null) {
      initialDir = p.dirname(lastSavedPath!);
    }

    final result = await _picker.pickFiles(
      dialogTitle: 'Choose Kontinuum backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
      allowMultiple: false,
      lockParentWindow: true,
      initialDirectory: initialDir,
    );
    if (result == null || result.files.isEmpty) {
      return Uint8List(0); // treat as cancel
    }
    final file = result.files.single;
    if (file.bytes != null) {
      return Uint8List.fromList(file.bytes!);
    }
    if (file.path == null) {
      return Uint8List(0);
    }
    return File(file.path!).readAsBytes();
  }
}
