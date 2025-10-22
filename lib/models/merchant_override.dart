import 'package:hive/hive.dart';

part 'merchant_override.g.dart';

@HiveType(typeId: 41)
class MerchantOverride extends HiveObject {
  MerchantOverride({
    required this.merchantKey,
    required this.category,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Normalized merchant name (lowercased, trimmed).
  @HiveField(0)
  String merchantKey;

  /// Canonical category name.
  @HiveField(1)
  String category;

  @HiveField(2)
  DateTime updatedAt;

  static String keyFor(String? merchant) =>
      (merchant ?? '').trim().toLowerCase();
}
