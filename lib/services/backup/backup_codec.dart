import 'dart:convert';

import 'package:hive/hive.dart';
// We rely on Hive's internal reader/writer to preserve adapter payloads.
// ignore: implementation_imports
import 'package:hive/src/binary/binary_reader_impl.dart';
// ignore: implementation_imports
import 'package:hive/src/binary/binary_writer_impl.dart';
// ignore: implementation_imports
import 'package:hive/src/registry/type_registry_impl.dart';

/// JSON-friendly snapshot of a single Hive entry.
class BackupEntry {
  final dynamic key;
  final String data; // base64-encoded binary
  final int? typeId;

  const BackupEntry({
    required this.key,
    required this.data,
    this.typeId,
  });

  Map<String, dynamic> toJson() =>
      {'key': key, 'data': data, if (typeId != null) 'typeId': typeId};

  factory BackupEntry.fromJson(Map<String, dynamic> json) => BackupEntry(
        key: json['key'],
        data: json['data'] as String,
        typeId: (json['typeId'] as num?)?.toInt(),
      );
}

/// Group of entries for a single box.
class BackupBoxDump {
  final String name;
  final List<BackupEntry> entries;

  const BackupBoxDump({
    required this.name,
    required this.entries,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory BackupBoxDump.fromJson(Map<String, dynamic> json) => BackupBoxDump(
        name: json['name'] as String,
        entries: (json['entries'] as List? ?? const [])
            .map((e) => BackupEntry.fromJson(
                  (e as Map?)?.cast<String, dynamic>() ?? const {},
                ))
            .toList(),
      );
}

/// Encodes/decodes Hive values into a base64 envelope using Hive's own
/// binary reader/writer so we capture adapter typeIds and field maps without
/// hand-written JSON mappers.
class BackupValueCodec {
  BackupValueCodec._();

  static final TypeRegistryImpl _registry = Hive as TypeRegistryImpl;

  static BackupEntry encode(dynamic key, dynamic value) {
    final writer = BinaryWriterImpl(_registry)..write(value);
    final bytes = writer.toBytes();
    final typeId = _registry.findAdapterForValue(value)?.typeId;
    return BackupEntry(
      key: key,
      data: base64Encode(bytes),
      typeId: typeId,
    );
  }

  static dynamic decode(BackupEntry entry) {
    final bytes = base64Decode(entry.data);
    final reader = BinaryReaderImpl(bytes, _registry);
    return reader.read();
  }
}
