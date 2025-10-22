import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:plaid_flutter/plaid_flutter.dart';

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

  Future<void> dispose() => _cancelListeners();
}
