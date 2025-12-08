import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:kontinuum/ui/screens/budget/models/budget_models.dart';
import 'package:kontinuum/services/transactions_store.dart';

typedef LinkResult = ({
  String? itemId,
  String? institutionId,
  String? institutionName,
});
typedef LinkFailure = ({String? code, String? message});

/// Opens Plaid Link, exchanges the public_token on your backend,
/// and (optionally) triggers a sync on the server.
class BankLinkService {
  BankLinkService({required this.baseUrl, required this.userId});

  final String baseUrl;
  final String userId;

  StreamSubscription<LinkSuccess>? _successSub;
  StreamSubscription<LinkEvent>? _eventSub;
  StreamSubscription<LinkExit>? _exitSub;

  String get _redirectUri => 'kontinuum://plaid/oauth';
  String get _androidPackageName => 'com.example.kontinuum';
  String get _iosBundleId => 'com.example.kontinuum';

  // Normalize localhost/ports for emulators.
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

  // Try a couple of base URLs before giving up.
  Future<T> _tryBases<T>(Future<T> Function(String base) run) async {
    final primary = _normalizeBase(baseUrl);
    final u = Uri.parse(primary);

    final hosts = <String>{u.host};
    if (Platform.isAndroid &&
        (u.host == 'localhost' || u.host == '127.0.0.1')) {
      hosts.add('10.0.2.2');
    }

    final ports = <int>[
      if (u.hasPort) u.port else 4001,
      if (!u.hasPort || u.port != 4000) 4000,
    ].toSet().toList();

    final tried = <String>[];
    for (final h in hosts) {
      for (final p in ports) {
        final candidate = u.replace(host: h, port: p).toString();
        tried.add(candidate);
        try {
          return await run(candidate);
        } catch (e) {
          final msg = e.toString();
          final connRefused = msg.contains('Connection refused') ||
              msg.contains('errno = 61') ||
              msg.contains('OS Error');
          if (!connRefused) rethrow;
        }
      }
    }
    if (primary != baseUrl) {
      return await run(baseUrl);
    }
    throw Exception('Could not reach API at any of: ${tried.join(', ')}');
  }

  /// Standard Link (new institution): gets a link_token, opens Link, exchanges public_token.
  Future<void> openLink({
    void Function(LinkResult result)? onSuccess,
    void Function(LinkFailure error)? onError,
    void Function(LinkEvent event)? onEvent,
  }) async {
    try {
      final String linkToken = await _fetchLinkToken();

      await _cancelListeners();

      _eventSub = PlaidLink.onEvent.listen((event) {
        if (onEvent != null) onEvent(event);
      });

      _successSub = PlaidLink.onSuccess.listen((success) async {
        try {
          final exchange = await _exchangePublicToken(success.publicToken);

          final itemId = (exchange['itemId'] ??
                  exchange['item_id'] ??
                  (exchange['item'] is Map ? exchange['item']['id'] : null))
              ?.toString();

          if (itemId != null) {
            await _triggerSync(itemId);
          }

          onSuccess?.call((
            itemId: itemId,
            institutionId: success.metadata.institution?.id,
            institutionName: success.metadata.institution?.name,
          ));
        } catch (e) {
          onError?.call((code: 'exchange_failed', message: e.toString()));
        }
      });

      _exitSub = PlaidLink.onExit.listen((exit) {
        final err = exit.error;
        if (err != null) {
          final d = err as dynamic; // tolerate older shapes
          final code = (d.code ?? d.errorCode ?? d.type)?.toString();
          final msg =
              (d.displayMessage ?? d.message ?? d.errorMessage)?.toString();
          onError?.call((code: code, message: msg ?? 'Exited with error'));
        } else {
          onError?.call((code: 'exit', message: 'User exited Plaid Link.'));
        }
      });

      final conf = LinkTokenConfiguration(token: linkToken);
      await PlaidLink.create(configuration: conf);
      await PlaidLink.open();
    } catch (e) {
      onError?.call((code: 'link_token_failed', message: e.toString()));
    }
  }

  /// Link Update (re-auth/fix): open Link using an update token (DO NOT exchange public_token).
  Future<void> openLinkToken(
    String linkToken, {
    void Function(LinkResult result)? onSuccess,
    void Function(LinkFailure error)? onError,
    void Function(LinkEvent event)? onEvent,
  }) async {
    try {
      await _cancelListeners();

      _eventSub = PlaidLink.onEvent.listen((event) {
        if (onEvent != null) onEvent(event);
      });

      _successSub = PlaidLink.onSuccess.listen((success) async {
        // In update mode, you typically do NOT exchange a public_token.
        onSuccess?.call((
          itemId: null,
          institutionId: success.metadata.institution?.id,
          institutionName: success.metadata.institution?.name,
        ));
      });

      _exitSub = PlaidLink.onExit.listen((exit) {
        final err = exit.error;
        if (err != null) {
          final d = err as dynamic;
          final code = (d.code ?? d.errorCode ?? d.type)?.toString();
          final msg =
              (d.displayMessage ?? d.message ?? d.errorMessage)?.toString();
          onError?.call((code: code, message: msg ?? 'Exited with error'));
        } else {
          onError?.call((code: 'exit', message: 'User exited Plaid Link.'));
        }
      });

      final conf = LinkTokenConfiguration(token: linkToken);
      await PlaidLink.create(configuration: conf);
      await PlaidLink.open();
    } catch (e) {
      onError?.call((code: 'link_update_failed', message: e.toString()));
    }
  }

  Future<String> _fetchLinkToken() async {
    return _tryBases<String>((base) async {
      final uri = Uri.parse('$base/plaid/link_token');
      final payload = <String, dynamic>{
        'userId': userId,
        // 👇 Helpful metadata (your API can ignore if unused)
        'redirectUri': _redirectUri,
        'androidPackageName': _androidPackageName,
        'iosBundleId': _iosBundleId,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      };

      final res = await http.post(
        uri,
        headers: {'content-type': 'application/json'},
        body: json.encode(payload),
      );
      if (res.statusCode != 200) {
        throw Exception('link_token ${res.statusCode}: ${res.body}');
      }
      final map = json.decode(res.body) as Map<String, dynamic>;
      final token = map['link_token'] ?? map['linkToken'];
      if (token is! String) {
        throw Exception('Invalid link_token response: ${res.body}');
      }
      return token;
    });
  }

  Future<Map<String, dynamic>> _exchangePublicToken(String publicToken) async {
    return _tryBases<Map<String, dynamic>>((base) async {
      final uri = Uri.parse('$base/plaid/exchange_public_token');
      final res = await http.post(
        uri,
        headers: {'content-type': 'application/json'},
        body: json.encode({'public_token': publicToken, 'userId': userId}),
      );
      if (res.statusCode != 200) {
        throw Exception('exchange_public_token ${res.statusCode}: ${res.body}');
      }
      return json.decode(res.body) as Map<String, dynamic>;
    });
  }

  Future<void> _triggerSync(String itemId) async {
    await _tryBases<void>((base) async {
      final uri = Uri.parse('$base/plaid/sync');
      final res = await http.post(
        uri,
        headers: {'content-type': 'application/json'},
        body: json.encode({'userId': userId, 'itemId': itemId}),
      );
      if (res.statusCode != 200) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Warning: /plaid/sync -> ${res.statusCode} ${res.body}');
        }
      }
    });
  }

  Future<void> _cancelListeners() async {
    await _successSub?.cancel();
    await _eventSub?.cancel();
    await _exitSub?.cancel();
    _successSub = null;
    _eventSub = null;
    _exitSub = null;
  }

  /// Fetch account balances (stub implementation)
  Future<Map<String, dynamic>> fetchBalances() async {
    return _tryBases<Map<String, dynamic>>((base) async {
      final uri = Uri.parse('$base/finance/balances')
          .replace(queryParameters: {'userId': userId});
      final res = await http.get(
        uri,
        headers: {'content-type': 'application/json'},
      );
      if (res.statusCode == 404) {
        // Treat missing endpoint as no accounts rather than crashing UI.
        return <String, dynamic>{
          'checking': 0,
          'savings': 0,
          'currency': null,
          'hasAccounts': false,
        };
      }
      if (res.statusCode != 200) {
        throw Exception('fetchBalances ${res.statusCode}: ${res.body}');
      }
      return json.decode(res.body) as Map<String, dynamic>;
    });
  }

  String _formatYmd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, String> _queryWithoutNulls(Map<String, String?> input) {
    final result = <String, String>{};
    input.forEach((key, value) {
      if (value != null && value.isNotEmpty) {
        result[key] = value;
      }
    });
    return result;
  }

  /// Fetch cash flow snapshot combining live transactions + summary.
  Future<CashFlowSnapshot> fetchCashFlowSnapshot({
    required DateTime from,
    required DateTime to,
    String? accountType,
    String? flow,
    String? category,
    String? query,
    int? limit,
  }) async {
    return _tryBases<CashFlowSnapshot>((base) async {
      final since = _formatYmd(from);
      final until = _formatYmd(to);
      final txParams = _queryWithoutNulls({
        'userId': userId,
        'since': since,
        'until': until,
        'limit': (limit == null ? 200 : math.max(1, math.min(500, limit)))
            .toString(),
        'accountType': accountType,
        'flow': flow,
        'category': category,
        'q': query,
      });
      final summaryParams = _queryWithoutNulls({
        'userId': userId,
        'from': since,
        'to': until,
        'accountType': accountType,
        'flow': flow,
        'category': category,
        'q': query,
      });

      Future<Map<String, dynamic>> fetchJson(Uri uri) async {
        final res = await http.get(uri, headers: {
          'content-type': 'application/json',
        });
        if (res.statusCode == 404) {
          return const <String, dynamic>{};
        }
        if (res.statusCode != 200) {
          throw Exception(
              'fetchCashFlowSnapshot ${uri.path} ${res.statusCode}: ${res.body}');
        }
        return json.decode(res.body) as Map<String, dynamic>;
      }

      final txUri = Uri.parse('$base/finance/transactions')
          .replace(queryParameters: txParams);
      final summaryUri = Uri.parse('$base/finance/cashflow')
          .replace(queryParameters: summaryParams);

      final results = await Future.wait<Map<String, dynamic>>(
        [
          fetchJson(txUri),
          fetchJson(summaryUri),
        ],
        eagerError: true,
      );

      final txJson = results[0];
      final summaryJson = results[1];

      final transactions = <BankTransaction>[];
      final rawTxs = txJson['transactions'];
      if (rawTxs is List) {
        for (final raw in rawTxs) {
          if (raw is! Map) continue;
          final amount = (raw['amount'] as num?)?.toDouble() ?? 0.0;
          DateTime? posted;
          final dateStr = raw['date'] as String?;
          if (dateStr != null) {
            posted = DateTime.tryParse(dateStr);
          }
          final categoryPath = (raw['categoryPath'] as List?)
                  ?.map((e) => e?.toString() ?? '')
                  .where((e) => e.isNotEmpty)
                  .toList() ??
              const <String>[];
          transactions.add(
            BankTransaction(
              id: raw['id']?.toString() ?? UniqueKey().toString(),
              accountId: raw['accountId']?.toString() ?? '',
              merchant: raw['merchant'] as String?,
              name: raw['name'] as String?,
              category: raw['category'] as String?,
              categoryPath: categoryPath,
              isExpense: raw['isExpense'] == true,
              amount: amount,
              flow: raw['type'] as String?,
              status: raw['status']?.toString() ?? 'posted',
              date: posted,
              amountCents: (raw['amountCents'] is num)
                  ? (raw['amountCents'] as num).toInt()
                  : 0,
              pendingTransactionId: raw['pendingTransactionId'] as String?,
              currency: raw['currency'] as String?,
              accountType: raw['accountType'] as String?,
              accountName: raw['accountName'] as String?,
            ),
          );
        }
      }

      CashFlowSummary? summary;
      if (summaryJson.isNotEmpty) {
        final inflow = (summaryJson['inflow'] as num?)?.toDouble() ?? 0.0;
        final outflow = (summaryJson['outflow'] as num?)?.toDouble() ?? 0.0;
        final fromStr = summaryJson['from'] as String?;
        final toStr = summaryJson['to'] as String?;
        final parsedFrom = fromStr != null ? DateTime.tryParse(fromStr) : from;
        final parsedTo = toStr != null ? DateTime.tryParse(toStr) : to;
        summary = CashFlowSummary(
          totalIncome: inflow,
          totalExpense: outflow,
          from: parsedFrom,
          to: parsedTo,
        );
      }

      final removedIds = TransactionsStore.allRemovedTransactionIds();
      List<BankTransaction> filteredTransactions = transactions;
      CashFlowSummary? filteredSummary = summary;
      if (removedIds.isNotEmpty) {
        final removedTxns = <BankTransaction>[];
        final keep = <BankTransaction>[];
        for (final txn in transactions) {
          if (removedIds.contains(txn.id)) {
            removedTxns.add(txn);
          } else {
            keep.add(txn);
          }
        }
        if (removedTxns.isNotEmpty) {
          filteredTransactions = keep;
          filteredSummary = _summaryWithoutRemoved(summary, removedTxns);
        }
      }

      return CashFlowSnapshot(
        transactions: filteredTransactions,
        summary: filteredSummary,
      );
    });
  }

  Future<void> dispose() => _cancelListeners();
}

CashFlowSummary? _summaryWithoutRemoved(
  CashFlowSummary? base,
  List<BankTransaction> removed,
) {
  if (base == null || removed.isEmpty) return base;
  double inflow = 0;
  double outflow = 0;
  for (final txn in removed) {
    final flow = (txn.flow ?? (txn.isExpense ? 'expense' : 'income')).toLowerCase();
    final amount = txn.amount.abs();
    if (flow == 'income') {
      inflow += amount;
    } else if (flow == 'expense') {
      outflow += amount;
    }
  }
  if (inflow == 0 && outflow == 0) return base;
  return CashFlowSummary(
    totalIncome: math.max(0.0, base.inflow - inflow),
    totalExpense: math.max(0.0, base.outflow - outflow),
    from: base.from,
    to: base.to,
  );
}
