import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/notification_manager.dart';

void main() {
  group('NotificationManager.generateNotificationId', () {
    test('generates consistent IDs for same inputs', () {
      final text = 'Buy groceries';
      final scheduledDate = DateTime(2026, 3, 29, 14, 30);
      final filePath = '/vault/tasks.md';

      final id1 = NotificationManager.generateNotificationId(
        text: text,
        scheduledDate: scheduledDate,
        filePath: filePath,
      );

      final id2 = NotificationManager.generateNotificationId(
        text: text,
        scheduledDate: scheduledDate,
        filePath: filePath,
      );

      expect(id1, equals(id2));
    });

    test('generates different IDs for different inputs', () {
      final baseDate = DateTime(2026, 3, 29, 14, 30);
      final basePath = '/vault/tasks.md';

      final id1 = NotificationManager.generateNotificationId(
        text: 'Buy groceries',
        scheduledDate: baseDate,
        filePath: basePath,
      );

      final id2 = NotificationManager.generateNotificationId(
        text: 'Team meeting',
        scheduledDate: baseDate,
        filePath: basePath,
      );

      final id3 = NotificationManager.generateNotificationId(
        text: 'Buy groceries',
        scheduledDate: DateTime(2026, 3, 29, 15, 30),
        filePath: basePath,
      );

      final id4 = NotificationManager.generateNotificationId(
        text: 'Buy groceries',
        scheduledDate: baseDate,
        filePath: '/vault/daily.md',
      );

      expect(id1, isNot(equals(id2)));
      expect(id1, isNot(equals(id3)));
      expect(id1, isNot(equals(id4)));
    });

    test('handles null filePath correctly', () {
      final text = 'Buy groceries';
      final scheduledDate = DateTime(2026, 3, 29, 14, 30);

      final id1 = NotificationManager.generateNotificationId(
        text: text,
        scheduledDate: scheduledDate,
        filePath: null,
      );

      final id2 = NotificationManager.generateNotificationId(
        text: text,
        scheduledDate: scheduledDate,
        filePath: null,
      );

      final id3 = NotificationManager.generateNotificationId(
        text: text,
        scheduledDate: scheduledDate,
        filePath: '/vault/tasks.md',
      );

      expect(id1, equals(id2));
      expect(id1, isNot(equals(id3)));
    });

    test('generates IDs within 32-bit signed integer range', () {
      final testCases = [
        ('Short', DateTime(2026, 1, 1), '/a.md'),
        (
          'Very long task description with many words',
          DateTime(2026, 12, 31, 23, 59, 59),
          '/very/long/path/file.md'
        ),
        ('Special chars: @#\$%^&*()', DateTime(2038, 1, 19), null),
      ];

      for (final (text, date, path) in testCases) {
        final id = NotificationManager.generateNotificationId(
          text: text,
          scheduledDate: date,
          filePath: path,
        );

        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(2147483647));
      }
    });

    test('handles millisecond precision in dates', () {
      final text = 'Buy groceries';
      final filePath = '/vault/tasks.md';

      final id1 = NotificationManager.generateNotificationId(
        text: text,
        scheduledDate: DateTime(2026, 3, 29, 14, 30, 0, 0),
        filePath: filePath,
      );

      final id2 = NotificationManager.generateNotificationId(
        text: text,
        scheduledDate: DateTime(2026, 3, 29, 14, 30, 0, 1),
        filePath: filePath,
      );

      expect(id1, isNot(equals(id2)));
    });
  });
}
