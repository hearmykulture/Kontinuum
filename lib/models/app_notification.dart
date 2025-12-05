import 'package:kontinuum/core/time/app_clock.dart';

enum NotificationModule {
  workouts,
  missions,
  budget,
  calendar,
  tasks,
}

enum NotificationKind {
  sessionInProgress,
  missedWorkout,
  restDayReminder,
  missionOverdue,
  missionRefresh,
  billUpcoming,
  billOverdue,
  categoryOverBudget,
  lowBalanceForBill,
  eventStartingSoon,
  reminderDue,
  overlappingEvents,
  taskDueToday,
}

enum NotificationSeverity {
  critical,
  nonCritical,
}

enum NotificationActionType {
  resume,
  end,
  pay,
  snooze,
  dismiss,
  open,
  complete,
  reschedule,
  custom,
}

class NotificationAction {
  const NotificationAction({
    required this.label,
    required this.type,
    this.payload,
  });

  final String label;
  final NotificationActionType type;
  final Map<String, dynamic>? payload;

  NotificationAction copyWith({
    String? label,
    NotificationActionType? type,
    Map<String, dynamic>? payload,
  }) {
    return NotificationAction(
      label: label ?? this.label,
      type: type ?? this.type,
      payload: payload ?? this.payload,
    );
  }

  factory NotificationAction.fromMap(Map<dynamic, dynamic> map) {
    return NotificationAction(
      label: map['label'] as String? ?? '',
      type: NotificationActionType.values.firstWhere(
        (v) => v.name == map['type'],
        orElse: () => NotificationActionType.custom,
      ),
      payload: (map['payload'] as Map?)?.cast<String, dynamic>(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'type': type.name,
      if (payload != null) 'payload': payload,
    };
  }
}

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.module,
    required this.kind,
    required this.title,
    required this.detail,
    this.meta,
    required this.severity,
    DateTime? createdAt,
    this.actions = const [],
    this.groupKey,
    this.payload,
    this.bundleCount = 1,
    this.expiresAt,
  }) : createdAt = createdAt ?? AppClock.now();

  final String id;
  final NotificationModule module;
  final NotificationKind kind;
  final String title;
  final String detail;
  final String? meta;
  final NotificationSeverity severity;
  final DateTime createdAt;
  final List<NotificationAction> actions;
  final String? groupKey;
  final Map<String, dynamic>? payload;
  final int bundleCount;
  final DateTime? expiresAt;

  bool get isBundled => bundleCount > 1;

  NotificationItem copyWith({
    String? id,
    NotificationModule? module,
    NotificationKind? kind,
    String? title,
    String? detail,
    String? meta,
    NotificationSeverity? severity,
    DateTime? createdAt,
    List<NotificationAction>? actions,
    String? groupKey,
    Map<String, dynamic>? payload,
    int? bundleCount,
    DateTime? expiresAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      module: module ?? this.module,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      meta: meta ?? this.meta,
      severity: severity ?? this.severity,
      createdAt: createdAt ?? this.createdAt,
      actions: actions ?? this.actions,
      groupKey: groupKey ?? this.groupKey,
      payload: payload ?? this.payload,
      bundleCount: bundleCount ?? this.bundleCount,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  factory NotificationItem.fromMap(Map<dynamic, dynamic> map) {
    final rawActions = (map['actions'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(NotificationAction.fromMap)
            .toList() ??
        const <NotificationAction>[];
    DateTime parseDate(dynamic raw) {
      if (raw is DateTime) return raw;
      if (raw is String && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
      return AppClock.now();
    }

    return NotificationItem(
      id: map['id'] as String? ?? '',
      module: NotificationModule.values.firstWhere(
        (m) => m.name == map['module'],
        orElse: () => NotificationModule.tasks,
      ),
      kind: NotificationKind.values.firstWhere(
        (k) => k.name == map['kind'],
        orElse: () => NotificationKind.taskDueToday,
      ),
      title: map['title'] as String? ?? '',
      detail: map['detail'] as String? ?? '',
      meta: map['meta'] as String?,
      severity: NotificationSeverity.values.firstWhere(
        (s) => s.name == map['severity'],
        orElse: () => NotificationSeverity.nonCritical,
      ),
      createdAt: parseDate(map['createdAt']),
      actions: rawActions,
      groupKey: map['groupKey'] as String?,
      payload: (map['payload'] as Map?)?.cast<String, dynamic>(),
      bundleCount: map['bundleCount'] is int ? map['bundleCount'] as int : 1,
      expiresAt: map.containsKey('expiresAt') ? parseDate(map['expiresAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'module': module.name,
      'kind': kind.name,
      'title': title,
      'detail': detail,
      'meta': meta,
      'severity': severity.name,
      'createdAt': createdAt.toIso8601String(),
      'actions': actions.map((a) => a.toMap()).toList(),
      'groupKey': groupKey,
      if (payload != null) 'payload': payload,
      'bundleCount': bundleCount,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    };
  }
}
