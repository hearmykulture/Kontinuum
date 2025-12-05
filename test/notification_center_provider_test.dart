import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kontinuum/models/app_notification.dart';
import 'package:kontinuum/providers/notification_center_provider.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  late NotificationCenterProvider provider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nc_provider_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('notification_center_box');
    provider = NotificationCenterProvider(box);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
    await Hive.deleteBoxFromDisk('notification_center_box');
    Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  NotificationItem item({
    required String id,
    NotificationSeverity severity = NotificationSeverity.nonCritical,
    String? groupKey,
  }) {
    return NotificationItem(
      id: id,
      module: NotificationModule.tasks,
      kind: NotificationKind.taskDueToday,
      title: 'Test $id',
      detail: 'Detail $id',
      severity: severity,
      groupKey: groupKey,
    );
  }

  test('bundles by groupKey and increments count', () async {
    await provider.addAll([
      item(id: 'a', groupKey: 'bundle'),
      item(id: 'b', groupKey: 'bundle'),
    ]);

    expect(provider.activeNotifications.length, 1);
    final n = provider.activeNotifications.first;
    expect(n.bundleCount, 2);
    expect(n.title.startsWith('2x'), isTrue);
  });

  test('quiet hours moves non-critical to queued then releases', () async {
    await provider.add(item(id: 'non_crit'));
    expect(provider.activeNotifications.length, 1);
    expect(provider.queuedNotifications.length, 0);

    await provider.toggleQuietHours(true);
    expect(provider.activeNotifications.isEmpty, isTrue);
    expect(provider.queuedNotifications.length, 1);

    await provider.toggleQuietHours(false);
    expect(provider.queuedNotifications.isEmpty, isTrue);
    expect(provider.activeNotifications.length, greaterThanOrEqualTo(1));
  });

  test('clearNonCritical only removes non-critical', () async {
    await provider.addAll([
      item(id: 'non_crit'),
      item(id: 'crit', severity: NotificationSeverity.critical),
    ]);
    await provider.clearNonCritical();
    expect(provider.activeNotifications.length, 1);
    expect(
      provider.activeNotifications.first.severity,
      NotificationSeverity.critical,
    );
  });

  test('snooze removes then re-adds after duration', () async {
    await fakeAsync((async) async {
      await provider.add(item(id: 'snooze_me'));
      await provider.snooze('snooze_me', const Duration(minutes: 1));
      expect(provider.activeNotifications.isEmpty, isTrue);

      async.elapse(const Duration(minutes: 1, seconds: 1));
      // Allow microtasks to run after timer fire.
      await Future<void>.delayed(Duration.zero);
      expect(provider.activeNotifications.length, 1);
      expect(provider.activeNotifications.first.id, 'snooze_me');
    });
  });
}
