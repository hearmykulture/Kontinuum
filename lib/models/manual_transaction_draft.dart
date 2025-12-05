// lib/models/manual_transaction_draft.dart

/// Lightweight payload used when the user creates a manual transaction locally.
class ManualTransactionDraft {
  const ManualTransactionDraft({
    required this.title,
    required this.amountCents,
    required this.flow,
    required this.date,
    this.category,
    this.description,
    this.accountName,
    this.accountId,
    this.accountType,
    this.currency = 'USD',
  });

  final String title;
  final int amountCents;
  /// One of `income`, `expense`, or `transfer`.
  final String flow;
  final DateTime date;
  final String? category;
  final String? description;
  final String? accountName;
  final String? accountId;
  /// Optional logical type (`checking`, `savings`, etc.). Defaults to `manual`.
  final String? accountType;
  final String currency;

  String get normalizedFlow => flow.toLowerCase().trim();

  bool get isExpense => normalizedFlow == 'expense';

  bool get isTransfer => normalizedFlow == 'transfer';
}
