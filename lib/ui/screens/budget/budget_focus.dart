enum BudgetFocusTarget {
  upcomingBills,
}

class BudgetBillFocus {
  const BudgetBillFocus({
    this.billKey,
    this.budgetId,
    this.name,
    this.amountCents,
    this.dueDate,
  });

  final String? billKey;
  final String? budgetId;
  final String? name;
  final int? amountCents;
  final DateTime? dueDate;

  bool get hasData =>
      billKey != null ||
      name != null ||
      amountCents != null ||
      dueDate != null;
}
