import 'package:kontinuum/models/app_notification.dart';
import 'package:kontinuum/providers/notification_center_provider.dart';

/// Lightweight bridge so non-UI layers can emit notifications without
/// tight widget coupling. Attach the live provider at app startup.
class NotificationDispatcher {
  static NotificationCenterProvider? _center;

  static void attach(NotificationCenterProvider provider) {
    _center = provider;
  }

  static NotificationCenterProvider? get center => _center;

  static Future<void> add(NotificationItem item) async {
    final c = _center;
    if (c == null) return;
    await c.add(item);
  }

  static Future<void> dismiss(String id) async {
    final c = _center;
    if (c == null) return;
    await c.dismiss(id);
  }
}
