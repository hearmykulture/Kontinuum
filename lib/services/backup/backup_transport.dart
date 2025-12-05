import 'dart:typed_data';

/// Abstraction so backup bytes can be stored or loaded from multiple transports
/// (local file picker today, cloud/iCloud/Drive later) without touching
/// serialization internals.
abstract class BackupTransport {
  /// Human-readable label, e.g. "Local file" or "iCloud Drive".
  String get label;

  /// Persist the backup bytes somewhere the user can access.
  Future<void> save(Uint8List bytes, {String? suggestedFileName});

  /// Load backup bytes from the chosen transport.
  Future<Uint8List> load();
}
