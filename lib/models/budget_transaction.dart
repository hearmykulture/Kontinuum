import 'package:hive/hive.dart';

part 'budget_transaction.g.dart';

@HiveType(typeId: 40)
class BudgetTransaction extends HiveObject {
  BudgetTransaction({
    required this.id,
    required this.accountId,
    required this.date,
    required this.amountCents,
    required this.isExpense,
    required this.status,
    this.category,
    this.merchant,
    this.memo,
    this.pendingTransactionId,
    this.currency,
    this.reviewed = false,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String accountId;

  @HiveField(2)
  DateTime? date;

  @HiveField(3)
  int amountCents;

  @HiveField(4)
  bool isExpense;

  /// 'pending' | 'posted' | 'removed'
  @HiveField(5)
  String status;

  @HiveField(6)
  String? category;

  @HiveField(7)
  String? merchant;

  @HiveField(8)
  String? memo;

  @HiveField(9)
  String? pendingTransactionId;

  @HiveField(10)
  String? currency;

  @HiveField(11)
  bool reviewed;

  bool get removed => status == 'removed';

  BudgetTransaction copyWith({
    String? category,
    bool? reviewed,
    String? status,
  }) =>
      BudgetTransaction(
        id: id,
        accountId: accountId,
        date: date,
        amountCents: amountCents,
        isExpense: isExpense,
        status: status ?? this.status,
        category: category ?? this.category,
        merchant: merchant,
        memo: memo,
        pendingTransactionId: pendingTransactionId,
        currency: currency,
        reviewed: reviewed ?? this.reviewed,
      );

  static BudgetTransaction fromApi(Map<String, dynamic> j) {
    final rawAmount = (j['amount'] as num?) ?? 0;
    final amountCents =
        (j['amountCents'] as num?)?.toInt() ?? (rawAmount * 100).round();

    final categoryPath =
        (j['categoryPath'] as List?)?.map((e) => e.toString()).toList() ??
            const <String>[];
    final category = (j['category'] as String?) ??
        (categoryPath.isNotEmpty ? categoryPath.first : null);

    return BudgetTransaction(
      id: j['id'] as String,
      accountId: j['accountId'] as String,
      date: j['date'] == null ? null : DateTime.parse(j['date'] as String),
      amountCents: amountCents,
      isExpense: (j['isExpense'] as bool?) ?? (amountCents < 0), // ← safer
      status: (j['status'] as String?) ?? 'posted',
      category: category,
      merchant: j['merchant'] as String?,
      memo: j['name'] as String?,
      pendingTransactionId: j['pendingTransactionId'] as String?,
      currency: j['currency'] as String?,
      reviewed: (j['reviewed'] as bool?) ?? false,
    );
  }
}
