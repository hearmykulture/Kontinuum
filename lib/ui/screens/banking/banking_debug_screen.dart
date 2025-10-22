import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ✅ local store + models
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kontinuum/services/budget_boxes.dart';
import 'package:kontinuum/services/transactions_store.dart';
import 'package:kontinuum/models/budget_transaction.dart';

// (optional) sync helper for “last synced” time
import 'package:kontinuum/services/bank_sync_service.dart';

import 'package:kontinuum/ui/screens/budget/theme/budget_theme.dart';
import 'package:kontinuum/services/bank_link_service.dart';

/// ===== ReviewChip (listens to Hive and opens the sheet) =====
class ReviewChip extends StatelessWidget {
  const ReviewChip({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: BudgetBoxes.tx.listenable(),
      builder: (_, __, ___) {
        final count = TransactionsStore.unreviewedNewestFirst().length;
        if (count == 0) return const SizedBox.shrink();
        return ActionChip(
          label: Text('Review $count unassigned'),
          onPressed: () => showReviewTransactionsSheet(context),
        );
      },
    );
  }
}

/// Top-level helper so any widget can open the review UI.
Future<void> showReviewTransactionsSheet(BuildContext context) async {
  final items = TransactionsStore.unreviewedNewestFirst();
  if (items.isEmpty) {
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No unreviewed transactions')),
    );
    return;
  }

  // ignore: use_build_context_synchronously
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) {
      return DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.9,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        builder: (ctx, scroll) {
          final list = TransactionsStore.unreviewedNewestFirst();
          return Column(
            children: [
              const SizedBox(height: 8),
              const Text('Review Transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final t = list[i];
                    final amt = NumberFormat.currency(symbol: '\$')
                        .format(t.amountCents / 100.0); // cents→dollars

                    return ListTile(
                      title: Text(
                        t.merchant ?? t.memo ?? '(no merchant)',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text([
                        if (t.date != null)
                          DateFormat('yyyy-MM-dd').format(t.date!),
                        t.category ?? 'Uncategorized',
                        t.status,
                      ].join(' • ')),
                      trailing: Text(
                        amt,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: t.isExpense
                              ? Colors.redAccent
                              : Colors.tealAccent.shade700,
                        ),
                      ),
                      onTap: () async {
                        final picked =
                            await _pickCategory(ctx, initial: t.category);
                        if (picked != null) {
                          await TransactionsStore.markReviewed(
                            txnId: t.id,
                            setCategory: picked,
                            merchantForOverride: t.merchant,
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<String?> _pickCategory(BuildContext context, {String? initial}) async {
  const cats = [
    'Food and Drink',
    'Transportation',
    'Shopping',
    'Travel',
    'Entertainment',
    'Personal Care',
    'Services',
    'Healthcare',
    'Home',
    'Rent & Utilities',
    'Financial',
    'Income',
    'Government & Non-Profit',
    'Loan Payments',
    'Uncategorized',
  ];
  return await showModalBottomSheet<String>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        const Text('Pick Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final c in cats)
          ListTile(
            title: Text(c),
            selected: c == initial,
            onTap: () => Navigator.pop(context, c),
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

/// ===== Models matching your server responses =====

class BankAccount {
  final String id;
  final String plaidAccountId;
  final String itemId;
  final String? name;
  final String? mask;
  final String? subtype;
  final String? currency;
  final num? balance;

  BankAccount.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        plaidAccountId = j['plaidAccountId'] as String,
        itemId = j['itemId'] as String,
        name = j['name'] as String?,
        mask = j['mask'] as String?,
        subtype = j['subtype'] as String?,
        currency = j['currency'] as String?,
        balance = j['balance'] as num?;
}

class TransactionDto {
  final String id;
  final String accountId;
  final DateTime? date;
  final num amount; // original; we render with amountCents
  final int amountCents;
  final bool isExpense;
  final String status;
  final String? name;
  final String? merchant;
  final List<String> categoryPath;
  final String? pendingTransactionId;
  final String? currency;

  TransactionDto.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        accountId = j['accountId'] as String,
        date = j['date'] == null ? null : DateTime.parse(j['date'] as String),
        amount = (j['amount'] as num?) ?? 0,
        amountCents = (j['amountCents'] as num?)?.toInt() ??
            (((j['amount'] as num?) ?? 0) * 100).round(),
        isExpense =
            (j['isExpense'] as bool?) ?? (((j['amount'] as num?) ?? 0) < 0),
        status = j['status'] as String,
        name = j['name'] as String?,
        merchant = j['merchant'] as String?,
        categoryPath = ((j['categoryPath'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        pendingTransactionId = j['pendingTransactionId'] as String?,
        currency = j['currency'] as String?;
}

class BudgetVsActualRow {
  final String category;
  final num budget;
  final num actual;
  final num variance;
  final num? pct;

  BudgetVsActualRow.fromJson(Map<String, dynamic> j)
      : category = j['category'] as String,
        budget = (j['budget'] as num?) ?? 0,
        actual = (j['actual'] as num?) ?? 0,
        variance = (j['variance'] as num?) ?? 0,
        pct = j['pct'] as num?;
}

/// ===== Simple banner model (client-only) =====
class _BannerMsg {
  _BannerMsg(this.code, this.message, {this.actionLabel, this.action});
  final String code;
  final String message;
  final String? actionLabel;
  final VoidCallback? action;
}

/// ===== Screen =====

class BankingDebugScreen extends StatefulWidget {
  const BankingDebugScreen({
    super.key,
    this.defaultBaseUrl = 'http://localhost:4001',
    required this.userId,
  });

  final String defaultBaseUrl;
  final String userId;

  @override
  State<BankingDebugScreen> createState() => _BankingDebugScreenState();
}

class _BankingDebugScreenState extends State<BankingDebugScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _baseCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _monthCtrl;

  bool _includeBalances = true;
  bool _loading = false;
  String? _error;

  List<_BannerMsg> _banners = [];

  List<BankAccount> _accounts = [];
  String? _selectedAccountId;

  List<TransactionDto> _txns = [];
  List<BudgetVsActualRow> _bva = [];
  List<_CatRow> _cashflowCats = [];

  DateTime? _lastSyncAt; // status chip

  final _money = NumberFormat.currency(symbol: '\$');
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _baseCtrl = TextEditingController(text: widget.defaultBaseUrl);
    _userCtrl = TextEditingController(text: widget.userId);
    _monthCtrl = TextEditingController(
      text: DateFormat('yyyy-MM').format(DateTime.now()),
    );
    _tabs = TabController(length: 4, vsync: this);

    _lastSyncAt = BankSyncService.lastSyncAt(widget.userId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _baseCtrl.dispose();
    _userCtrl.dispose();
    _monthCtrl.dispose();
    super.dispose();
  }

  String _normalizeBase(String base) {
    final trimmed = base.trim().replaceFirst(RegExp(r'/+$'), '');
    Uri u;
    try {
      u = Uri.parse(trimmed);
    } catch (_) {
      return trimmed;
    }
    if (Platform.isAndroid &&
        (u.host == 'localhost' || u.host == '127.0.0.1')) {
      u = u.replace(host: '10.0.2.2');
    }
    if (!u.hasPort) {
      u = u.replace(port: 4001);
    } else if (u.port == 4000) {
      u = u.replace(port: 4001);
    }
    return u.toString();
  }

  String get _base => _normalizeBase(_baseCtrl.text);

  String _timeAgo(DateTime? t) {
    if (t == null) return 'never';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 45) return 'just now';
    if (d.inMinutes < 2) return '1m ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 2) return '1h ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    final days = d.inDays;
    return days == 1 ? '1d ago' : '${days}d ago';
  }

  void _setBannersFromWarnings(List warningsAny) {
    final itemIdForAction = _selectedAccountId == null
        ? (_accounts.isNotEmpty ? _accounts.first.itemId : null)
        : _accounts.firstWhere((a) => a.id == _selectedAccountId!).itemId;

    final List<_BannerMsg> next = [];
    for (final w in warningsAny) {
      final code = (w is Map ? w['code'] : null)?.toString() ?? '';
      switch (code) {
        case 'ITEM_LOGIN_REQUIRED':
          next.add(_BannerMsg(
            code,
            'Your bank needs to be reconnected.',
            actionLabel: 'Fix',
            action: (itemIdForAction == null)
                ? null
                : () => _openUpdateLink(itemIdForAction),
          ));
          break;
        case 'INSTITUTION_DOWN':
        case 'INSTITUTION_NOT_RESPONDING':
          next.add(_BannerMsg(
            code,
            'Institution is temporarily unavailable. Try again later.',
          ));
          break;
        case 'RATE_LIMIT':
          next.add(_BannerMsg(
            code,
            'We are being rate limited. Try again shortly.',
          ));
          break;
      }
    }
    setState(() => _banners = next);
  }

  Future<void> _guard(Future<void> Function() fn) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAccounts() async => _guard(() async {
        final uri = Uri.parse(
          '$_base/finance/accounts'
          '?userId=${Uri.encodeQueryComponent(_userCtrl.text)}'
          '&includeBalances=$_includeBalances',
        );
        final res = await http.get(uri);
        if (res.statusCode != 200) {
          throw 'GET /accounts ${res.statusCode}: ${res.body}';
        }
        final data = json.decode(res.body) as Map<String, dynamic>;
        final rawList = (data['accounts'] as List?) ?? const [];
        final accounts = rawList
            .map((e) => BankAccount.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ))
            .toList();

        setState(() {
          _accounts = accounts;
          if (_accounts.indexWhere((a) => a.id == _selectedAccountId) == -1) {
            _selectedAccountId =
                (_accounts.isNotEmpty) ? _accounts.first.id : null;
          }
        });
      });

  // fetch → ingest → UI
  Future<void> _fetchTransactions() async => _guard(() async {
        final qp = <String, String>{
          'userId': _userCtrl.text,
          if (_selectedAccountId != null) 'accountId': _selectedAccountId!,
          'limit': '50',
        };
        final uri = Uri.parse('$_base/finance/transactions')
            .replace(queryParameters: qp);
        final res = await http.get(uri);
        if (res.statusCode != 200) {
          throw 'GET /transactions ${res.statusCode}: ${res.body}';
        }
        final data = json.decode(res.body) as Map<String, dynamic>;
        final rawList = (data['transactions'] as List?) ?? const [];
        final txns = rawList
            .map((e) => TransactionDto.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ))
            .toList();

        // ingest into Hive
        final normalized = rawList
            .map<Map<String, dynamic>>(
                (e) => (e as Map).cast<String, dynamic>())
            .toList();
        await TransactionsStore.ingestNormalized(normalized);

        // typed warnings list
        final List<dynamic> warnings =
            (data['warnings'] as List?)?.toList() ?? const <dynamic>[];
        _setBannersFromWarnings(warnings);

        setState(() => _txns = txns);
      });

  // Manual sync single item (to capture warnings), then fetch txns
  Future<void> _syncThenFetch() async {
    await _guard(() async {
      if (_accounts.isEmpty) await _fetchAccounts();
      if (_accounts.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No accounts yet')),
        );
        return;
      }
      final itemId = (_selectedAccountId == null)
          ? _accounts.first.itemId
          : _accounts.firstWhere((a) => a.id == _selectedAccountId!).itemId;

      final res = await http.post(
        Uri.parse('$_base/plaid/sync'),
        headers: {'content-type': 'application/json'},
        body: json.encode({'itemId': itemId}),
      );
      if (res.statusCode != 200) {
        throw 'POST /plaid/sync ${res.statusCode}: ${res.body}';
      }
      final data = json.decode(res.body);
      final List<dynamic> warnings =
          (data['warnings'] as List?)?.toList() ?? const <dynamic>[];
      _setBannersFromWarnings(warnings);

      _lastSyncAt = DateTime.now();
      await _fetchTransactions();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Synced')));
      setState(() {}); // update “Synced • …” chip
    });
  }

  Future<void> _seedBudgets() async => _guard(() async {
        final month = _monthCtrl.text.trim();
        final uri = Uri.parse('$_base/finance/budgets');
        final body = <String, Object?>{
          'userId': _userCtrl.text,
          'month': month,
          'items': const [
            {'category': 'Food and Drink', 'amount': 300},
            {'category': 'Travel', 'amount': 200},
          ],
        };
        final res = await http.put(
          uri,
          headers: {'content-type': 'application/json'},
          body: json.encode(body),
        );
        if (res.statusCode != 200) {
          throw 'PUT /budgets ${res.statusCode}: ${res.body}';
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seeded budgets for current month')),
        );
      });

  Future<void> _fetchBudgetVsActual() async => _guard(() async {
        final month = _monthCtrl.text.trim();
        final uri = Uri.parse(
          '$_base/finance/budget-vs-actual'
          '?userId=${Uri.encodeQueryComponent(_userCtrl.text)}'
          '&month=$month',
        );
        final res = await http.get(uri);
        if (res.statusCode != 200) {
          throw 'GET /budget-vs-actual ${res.statusCode}: ${res.body}';
        }
        final data = json.decode(res.body) as Map<String, dynamic>;
        final rowsRaw = (data['rows'] as List?) ?? const [];
        setState(() {
          _bva = rowsRaw
              .map((e) => BudgetVsActualRow.fromJson(
                    (e as Map).cast<String, dynamic>(),
                  ))
              .toList();
        });
      });

  Future<void> _fetchCashflowByCategory() async => _guard(() async {
        final month = _monthCtrl.text.trim();
        final from = '$month-01';
        final parts = month.split('-');
        final y = int.parse(parts[0]), m = int.parse(parts[1]);
        final firstNext = DateTime.utc(
          m == 12 ? y + 1 : y,
          m == 12 ? 1 : m + 1,
          1,
        );
        final lastThis = firstNext.subtract(const Duration(days: 1));
        final to = DateFormat('yyyy-MM-dd').format(lastThis);

        final uri = Uri.parse(
          '$_base/finance/cashflow/by-category'
          '?userId=${Uri.encodeQueryComponent(_userCtrl.text)}'
          '&from=$from&to=$to',
        );
        final res = await http.get(uri);
        if (res.statusCode != 200) {
          throw 'GET /cashflow/by-category ${res.statusCode}: ${res.body}';
        }
        final data = json.decode(res.body) as Map<String, dynamic>;
        final rows = (data['rows'] as List?) ?? const [];
        setState(() {
          _cashflowCats = rows.map((e) {
            final j = (e as Map).cast<String, dynamic>();
            return _CatRow(
              (j['category'] as String?) ?? 'Uncategorized',
              (j['spend'] as num?) ?? 0,
              (j['income'] as num?) ?? 0,
              (j['net'] as num?) ?? 0,
            );
          }).toList();
        });
      });

  Future<void> _openLink() async {
    final userId = _userCtrl.text.trim();
    if (userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a User ID first')),
      );
      return;
    }
    final svc = BankLinkService(baseUrl: _base, userId: userId);
    await svc.openLink(
      onSuccess: (r) async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Linked ${r.institutionName ?? r.itemId ?? "bank"}')),
        );
        await _fetchAccounts();
        await _syncThenFetch(); // initial sync after link
      },
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Link failed: ${e.code ?? ""} ${e.message ?? ""}')),
        );
      },
    );
  }

  Future<void> _openUpdateLink(String itemId) async {
    final userId = _userCtrl.text.trim();
    final res = await http.post(
      Uri.parse('$_base/plaid/link_token/update'),
      headers: {'content-type': 'application/json'},
      body: json.encode({'itemId': itemId, 'userId': userId}),
    );
    if (res.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update token error: ${res.statusCode}')),
      );
      return;
    }
    final linkToken = (json.decode(res.body) as Map)['link_token'] as String;
    final svc = BankLinkService(baseUrl: _base, userId: userId);
    await svc.openLinkToken(
      linkToken,
      onSuccess: (_) async {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Reconnected')));
        setState(() => _banners = []);
        await _syncThenFetch();
      },
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Re-link failed: ${e.code ?? ""} ${e.message ?? ""}')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mint = BudgetTheme.mint;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? BudgetTheme.bg : null,
      appBar: AppBar(
        backgroundColor: isDark ? BudgetTheme.bg : null,
        title: Row(
          children: [
            const Text('Banking Debug'),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Synced • ${_timeAgo(_lastSyncAt)}',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Accounts'),
            Tab(text: 'Transactions'),
            Tab(text: 'Cashflow'),
            Tab(text: 'Budget vs Actual'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Link bank',
            onPressed: _openLink,
            icon: const Icon(Icons.account_balance),
          ),
          IconButton(
            tooltip: 'Sync now',
            onPressed: _syncThenFetch,
            icon: const Icon(Icons.sync),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: ReviewChip()),
          ),
          IconButton(
            tooltip: 'Refresh tab',
            onPressed: () {
              switch (_tabs.index) {
                case 0:
                  _fetchAccounts();
                  break;
                case 1:
                  _fetchTransactions();
                  break;
                case 2:
                  _fetchCashflowByCategory();
                  break;
                case 3:
                  _fetchBudgetVsActual();
                  break;
              }
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Phase 11 banners
          if (_banners.isNotEmpty)
            Column(
              children: _banners.map((b) {
                return MaterialBanner(
                  backgroundColor: Colors.amber.withValues(alpha: 0.1),
                  content: Text(b.message),
                  actions: [
                    if (b.actionLabel != null && b.action != null)
                      TextButton(
                          onPressed: b.action, child: Text(b.actionLabel!)),
                    TextButton(
                      onPressed: () => setState(
                        () => _banners = _banners.where((x) => x != b).toList(),
                      ),
                      child: const Text('Dismiss'),
                    ),
                  ],
                );
              }).toList(),
            ),

          _ControlsBar(
            baseCtrl: _baseCtrl,
            userCtrl: _userCtrl,
            monthCtrl: _monthCtrl,
            includeBalances: _includeBalances,
            onToggleBalances: (v) => setState(() => _includeBalances = v),
            onFetchAccounts: _fetchAccounts,
            onFetchTxns: _fetchTransactions, // ingests
            onSeedBudgets: _seedBudgets,
            onFetchBva: _fetchBudgetVsActual,
            onFetchCashflow: _fetchCashflowByCategory,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('Error: $_error',
                  style: const TextStyle(color: Colors.redAccent)),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AccountsTab(
                  accounts: _accounts,
                  selectedAccountId: _selectedAccountId,
                  onPickAccount: (id) =>
                      setState(() => _selectedAccountId = id),
                ),
                // Transactions with pull-to-refresh
                _TxnsTab(
                  txns: _txns,
                  money: _money,
                  accountById: {for (final a in _accounts) a.id: a},
                  onRefresh: _syncThenFetch, // swipe down to sync + refresh
                ),
                _CashflowTab(rows: _cashflowCats, money: _money),
                _BvaTab(rows: _bva, money: _money, accent: mint),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ——— Controls row (Base URL, User, Month, Buttons)
class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.baseCtrl,
    required this.userCtrl,
    required this.monthCtrl,
    required this.includeBalances,
    required this.onToggleBalances,
    required this.onFetchAccounts,
    required this.onFetchTxns,
    required this.onSeedBudgets,
    required this.onFetchBva,
    required this.onFetchCashflow,
  });

  final TextEditingController baseCtrl;
  final TextEditingController userCtrl;
  final TextEditingController monthCtrl;
  final bool includeBalances;
  final ValueChanged<bool> onToggleBalances;
  final VoidCallback onFetchAccounts;
  final VoidCallback onFetchTxns;
  final VoidCallback onSeedBudgets;
  final VoidCallback onFetchBva;
  final VoidCallback onFetchCashflow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ignore: deprecated_member_use
    final bg =
        isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100;

    return Material(
      color: isDark ? BudgetTheme.bg : Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Field(
                width: 240, controller: baseCtrl, hint: 'Base URL', mono: true),
            const SizedBox(width: 8),
            _Field(
                width: 260, controller: userCtrl, hint: 'User ID', mono: true),
            const SizedBox(width: 8),
            _Field(
                width: 120, controller: monthCtrl, hint: 'YYYY-MM', mono: true),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Text('Balances',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Switch(value: includeBalances, onChanged: onToggleBalances),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Btn(label: 'Accounts', onTap: onFetchAccounts),
            const SizedBox(width: 6),
            _Btn(label: 'Txns', onTap: onFetchTxns),
            const SizedBox(width: 6),
            _Btn(label: 'Seed budgets', onTap: onSeedBudgets),
            const SizedBox(width: 6),
            _Btn(label: 'Budget vs Actual', onTap: onFetchBva),
            const SizedBox(width: 6),
            _Btn(label: 'Cashflow by Cat', onTap: onFetchCashflow),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.width,
    required this.controller,
    required this.hint,
    this.mono = false,
  });

  final double width;
  final TextEditingController controller;
  final String hint;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        style: TextStyle(
          fontFamily: mono ? 'monospace' : null,
          color: isDark ? Colors.white : null,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor:
            isDark ? BudgetTheme.mint : Theme.of(context).colorScheme.primary,
        foregroundColor: isDark ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

/// ——— Tab: Accounts
class _AccountsTab extends StatelessWidget {
  const _AccountsTab({
    required this.accounts,
    required this.selectedAccountId,
    required this.onPickAccount,
  });

  final List<BankAccount> accounts;
  final String? selectedAccountId;
  final ValueChanged<String?> onPickAccount;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Center(child: Text('No accounts loaded'));
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: selectedAccountId,
          hint: const Text('Select account (filters txns tab)'),
          onChanged: onPickAccount,
          items: [
            for (final a in accounts)
              DropdownMenuItem(
                value: a.id,
                child: Text(
                  '${a.name ?? 'Unnamed'} • ${a.subtype ?? '-'} • ${a.mask ?? '----'}',
                ),
              ),
          ],
        ),
        const Divider(height: 0),
        Expanded(
          child: ListView.separated(
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final a = accounts[i];
              return ListTile(
                title: Text(
                  a.name ?? '(no name)',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Subtype: ${a.subtype ?? '-'}   •   Mask: ${a.mask ?? '----'}   •   Currency: ${a.currency ?? '-'}',
                ),
                trailing: Text(
                  a.balance == null
                      ? '—'
                      : NumberFormat.currency(symbol: '\$').format(a.balance),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// ——— Tab: Transactions (with pull-to-refresh)
class _TxnsTab extends StatelessWidget {
  const _TxnsTab({
    required this.txns,
    required this.money,
    required this.accountById,
    this.onRefresh,
  });

  final List<TransactionDto> txns;
  final NumberFormat money;
  final Map<String, BankAccount> accountById;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: txns.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (_, i) {
        final t = txns[i];
        final a = accountById[t.accountId];
        final subtitle = [
          if (a != null) (a.name ?? a.subtype ?? a.id),
          if (t.date != null) DateFormat('yyyy-MM-dd').format(t.date!),
          t.currency ?? 'USD',
          'status: ${t.status}',
        ].join('  •  ');

        final amtStr = money.format(t.amountCents / 100.0);
        final color =
            t.isExpense ? Colors.redAccent : Colors.tealAccent.shade700;

        return ListTile(
          title: Text(
            t.name ?? '(no name)',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(subtitle),
          trailing: Text(
            amtStr,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        );
      },
    );

    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// ——— Tab: Cashflow by Category
class _CashflowTab extends StatelessWidget {
  const _CashflowTab({required this.rows, required this.money});
  final List<_CatRow> rows;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('No cashflow data loaded'));
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (_, i) {
        final r = rows[i];
        return ListTile(
          title: Text(
            r.category,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'Income: ${money.format(r.income)}   •   Spend: ${money.format(r.spend)}',
          ),
          trailing: Text(
            money.format(r.net),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: r.net >= 0 ? Colors.tealAccent.shade700 : Colors.redAccent,
            ),
          ),
        );
      },
    );
  }
}

class _CatRow {
  _CatRow(this.category, this.spend, this.income, this.net);
  final String category;
  final num spend;
  final num income;
  final num net;
}

/// ——— Tab: Budget vs Actual
class _BvaTab extends StatelessWidget {
  const _BvaTab({
    required this.rows,
    required this.money,
    required this.accent,
  });

  final List<BudgetVsActualRow> rows;
  final NumberFormat money;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('No budget vs actual data loaded'));
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (_, i) {
        final r = rows[i];
        final varianceColor =
            r.variance >= 0 ? Colors.tealAccent.shade700 : Colors.redAccent;
        return ListTile(
          title: Text(
            r.category,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'Budget: ${money.format(r.budget)}   •   Actual: ${money.format(r.actual)}',
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Δ ${money.format(r.variance)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: varianceColor,
                ),
              ),
              Text(
                r.pct == null ? '—' : '${(r.pct! * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
