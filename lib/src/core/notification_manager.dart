import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationManager {
  static NotificationManager? _instance;

  static NotificationManager getInstance() {
    if (_instance != null) return _instance!;

    _instance = NotificationManager._();
    return _instance!;
  }

  NotificationManager._();

  final _notificationPlugin = FlutterLocalNotificationsPlugin();
  static const String _snoozeActionId = 'snooze_5min';
  static const String _iosGeneralCategoryId = 'obsi_general';

  // Expose a handler to be usable from a top-level background callback
  Future<void> handleNotificationResponse(NotificationResponse response) async {
    try {
      if (response.actionId == _snoozeActionId) {
        // Parse payload for id and body
        int? originalId;
        String text = 'Reminder';
        String? tzName;
        final payload = response.payload;
        if (payload != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(payload);
            final dynamic rawId = data['id'];
            if (rawId is int) {
              originalId = rawId;
            } else if (rawId is num) {
              originalId = rawId.toInt();
            } else if (rawId is String) {
              originalId = int.tryParse(rawId);
            }
            if (data['body'] is String) {
              text = data['body'] as String;
            }
            if (data['tz'] is String) {
              tzName = data['tz'] as String;
            }
          } catch (_) {
            // Fallback to treating payload as plain text body
            text = payload;
          }
        }

        // Ensure timezone is initialized in background isolate
        try {
          tz.initializeTimeZones();
          if (tzName != null) {
            tz.setLocalLocation(tz.getLocation(tzName));
          }
        } catch (_) {
          // ignore; if tz is already initialized this may throw, safe to continue
        }

        // Cancel the original notification so it disappears immediately
        if (originalId != null) {
          await cancelNotification(originalId);
        }

        // Reschedule after 5 minutes, reuse the same id if available
        final newTime = DateTime.now().add(const Duration(minutes: 5));
        await createScheduledNotification(
          scheduledDate: newTime,
          text: text,
          notificationId: originalId ?? 0,
        );
      }
    } catch (e, st) {
      Logger()
          .e('Error handling notification response', error: e, stackTrace: st);
    }
  }

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
            defaultPresentAlert: true,
            defaultPresentBadge: true,
            defaultPresentSound: true,
            defaultPresentBanner: true,
            defaultPresentList: true,
            notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            _iosGeneralCategoryId,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(_snoozeActionId, 'Snooze 5 min'),
            ],
          )
        ]);

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS);

    // Initialize timezone database
    tz.initializeTimeZones();
    final String timeZoneName = tz.local.name;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    await _notificationPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        await NotificationManager.getInstance()
            .handleNotificationResponse(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  Future<bool> notificationPermissionGranted() async {
    bool status = false;
    if (Platform.isAndroid) {
      status = await _notificationPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
      Logger().i("Notification permission is granted: $status");

      if (status) {
        status = await _notificationPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.canScheduleExactNotifications() ??
            false;
      }

      Logger().i("Exact alarm permission is granted: $status");
    } else {
      //status = await Permission.notification.status == PermissionStatus.granted;
      status = true; // iOS always grants permission for notifications
    }
    return status;
  }

  Future<bool> requestExactAlarmPermission() async {
    bool status = false;
    if (Platform.isAndroid) {
      status = await _notificationPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;

      Logger().i("Notification permission is granted: $status");

      if (!status) {
        // Request permission to show notifications on Android 14+
        status = await _notificationPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
        Logger().i("Notification permission is requested and granted: $status");
      }

      if (status) {
        status = await _notificationPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.canScheduleExactNotifications() ??
            false;

        Logger().i("Exact alarm permission is granted: $status");

        if (!status) {
          status = await _notificationPlugin
                  .resolvePlatformSpecificImplementation<
                      AndroidFlutterLocalNotificationsPlugin>()
                  ?.requestExactAlarmsPermission() ??
              false;
          Logger()
              .i("Exact alarm permission is requested and granted: $status");
        }
      }
    } else {
      status = await _notificationPlugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
          false;
    }

    return status;
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Convert DateTime to TZDateTime
    final tz.TZDateTime tzScheduledDate =
        tz.TZDateTime.from(scheduledDate, tz.local);

    await _notificationPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: _iosGeneralCategoryId,
        ),
        android: _androidNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({'id': id, 'body': body, 'tz': tz.local.name}),
    );
  }

  static AndroidNotificationDetails _androidNotificationDetails() {
    return AndroidNotificationDetails(
      'obsi_channel_id',
      'obsi_channel_name',
      icon: 'ic_notification', // Path to your app icon
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
      ongoing: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _snoozeActionId,
          'Snooze 5 min',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
  }

  static int generateNotificationId({
    required String text,
    required DateTime scheduledDate,
    String? filePath,
  }) {
    final components = [
      if (filePath != null) filePath,
      text,
      scheduledDate.toIso8601String(),
    ];
    final combined = components.join('|');
    return combined.hashCode.abs() % 2147483647;
  }

  Future<void> createScheduledNotification({
    required DateTime scheduledDate,
    required String text,
    int notificationId = 0,
    String? filePath,
  }) async {
    // Check if the scheduled time is in the past
    if (scheduledDate.isBefore(DateTime.now())) {
      Logger().i("Scheduled date is in the past");
      return;
    }

    var permissionGranted = await notificationPermissionGranted();

    if (permissionGranted) {
      var id = notificationId;
      if (notificationId == 0) {
        id = generateNotificationId(
          text: text,
          scheduledDate: scheduledDate,
          filePath: filePath,
        );
      }
      Logger().i("Schedule notification with ID: $id at $scheduledDate");
      // Schedule the notification
      await _scheduleNotification(
        id: id, // Ensure the ID fits within 32-bit integer range
        title: 'VaultMate',
        body: text,
        scheduledDate: scheduledDate,
      );
    } else {
      Logger().i("Notification permission is not granted");
    }
  }

  Future<void> cancelAllNotifications() async {
    Logger().i("Canceling all notification");
    await _notificationPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    Logger().i("Canceling notification with ID: $id");
    await _notificationPlugin.cancel(id);
  }

  /// Schedules a daily recurring notification at the specified time
  ///
  /// [time] - The time of day when the notification should be triggered
  /// [title] - The title of the notification (defaults to 'VaultMate')
  /// [body] - The body text of the notification
  /// [notificationId] - Optional custom notification ID (auto-generated if not provided)
  ///
  /// Returns the notification ID that was used for scheduling
  Future<void> scheduleDailyNotification(
    int notificationId,
    TimeOfDay time,
    String body,
  ) async {
    // Check if notification permission is granted
    var permissionGranted = await notificationPermissionGranted();

    if (!permissionGranted) {
      Logger().i("Notification permission is not granted");
      throw Exception('Notification permission not granted');
    }

    // Create the scheduled time for today
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Convert DateTime to TZDateTime
    final tz.TZDateTime tzScheduledDate =
        tz.TZDateTime.from(scheduledDate, tz.local);

    Logger().i(
        "Scheduling daily notification with ID: $notificationId at ${time.hour}:${time.minute.toString().padLeft(2, '0')}");

    // Schedule the daily recurring notification
    await _notificationPlugin.zonedSchedule(
      notificationId,
      'VaultMate',
      body,
      tzScheduledDate,
      NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: _iosGeneralCategoryId,
        ),
        android: _androidNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.time, // This makes it repeat daily
      payload:
          jsonEncode({'id': notificationId, 'body': body, 'tz': tz.local.name}),
    );
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  // Ensure the singleton instance processes background taps
  await NotificationManager.getInstance().handleNotificationResponse(response);
}
