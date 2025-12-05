import 'dart:typed_data';

import 'package:kontinuum/services/backup/backup_transport.dart';

class BackupUserCancelled implements Exception {}

class LocalFileBackupTransport implements BackupTransport {
  @override
  String get label => 'Unsupported';

  @override
  Future<void> save(Uint8List bytes, {String? suggestedFileName}) {
    throw UnsupportedError('Local file transport is not available on this platform.');
  }

  @override
  Future<Uint8List> load() {
    throw UnsupportedError('Local file transport is not available on this platform.');
  }
}
