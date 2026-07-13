import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/savers/task_note_saver.dart';
import 'package:obsi/src/core/tasks/task.dart';

void main() {
  group('TaskNoteSaver', () {
    late TaskNoteSaver saver;

    setUp(() {
      saver = TaskNoteSaver();
    });

    group('toTaskNoteString', () {
      test('should create valid YAML front matter with all required fields',
          () {
        final task = Task(
          'Test task description',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 8, 16, 22, 33, 28),
          scheduled: DateTime(2025, 8, 16),
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('---'));
        expect(result, contains('status: open'));
        expect(result, contains('priority: normal'));
        expect(result, contains('scheduled: 2025-08-16'));
        expect(result, contains('dateCreated: 2025-08-16T22:33:28'));
        expect(result, contains('dateModified:'));
        expect(result, contains('tags:'));
        expect(result, contains('Test task description'));
      });

      test('should handle task with done status', () {
        final task = Task(
          'Completed task',
          status: TaskStatus.done,
          priority: TaskPriority.high,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 1, 1),
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('status: done'));
        expect(result, contains('priority: high'));
      });

      test('should handle task with in-progress status', () {
        final task = Task(
          'In progress task',
          status: TaskStatus.inprogress,
          priority: TaskPriority.medium,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 1, 1),
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('status: in-progress'));
        expect(result, contains('priority: medium'));
      });

      test('should handle task with cancelled status', () {
        final task = Task(
          'Cancelled task',
          status: TaskStatus.cancelled,
          priority: TaskPriority.low,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 1, 1),
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('status: cancelled'));
        expect(result, contains('priority: low'));
      });

      test('should handle all priority levels', () {
        final priorities = [
          TaskPriority.lowest,
          TaskPriority.low,
          TaskPriority.normal,
          TaskPriority.medium,
          TaskPriority.high,
          TaskPriority.highest,
        ];

        final expectedStrings = [
          'lowest',
          'low',
          'normal',
          'medium',
          'high',
          'highest',
        ];

        for (var i = 0; i < priorities.length; i++) {
          final task = Task(
            'Task',
            status: TaskStatus.todo,
            priority: priorities[i],
            created: DateTime(2025, 1, 1),
            scheduled: DateTime(2025, 1, 1),
          );

          final result = saver.toTaskNoteString(task);
          expect(result, contains('priority: ${expectedStrings[i]}'));
        }
      });

      test('should include tags in YAML format', () {
        final task = Task(
          'Task with tags #work #urgent',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 1, 1),
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('tags:'));
        expect(result, contains('  - work'));
        expect(result, contains('  - urgent'));
      });

      test('should preserve ISO 8601 datetime format with timezone', () {
        final task = Task(
          'Task',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 8, 16, 22, 33, 28, 696),
          scheduled: DateTime(2025, 8, 16),
        );

        final result = saver.toTaskNoteString(task);

        // Should contain ISO 8601 format
        expect(
            result,
            contains(
                RegExp(r'dateCreated: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')));
        expect(
            result,
            contains(
                RegExp(r'dateModified: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')));
      });
    });
    group('Edge Cases', () {
      test('should handle very long task description', () {
        final longDescription = 'A' * 10000;
        final task = Task(
          longDescription,
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 1, 1),
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('---'));
        expect(result, contains(longDescription));
      });

      test('should handle task with special characters in description', () {
        final task = Task(
          'Task with special chars: @#\$%^&*()[]{}|\\<>?',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 1, 1),
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('Task with special chars:'));
      });

      test('should handle task with unicode characters', () {
        final task = Task(
          'Task with unicode: 你好 🎉 café',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 1, 1),
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('你好'));
        expect(result, contains('🎉'));
        expect(result, contains('café'));
      });
    });

    group('Scheduled Date with Time', () {
      test('should format scheduled date without time', () {
        final task = Task(
          'Task with date only',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 11, 3),
          scheduledTime: false,
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('scheduled: 2025-11-03'));
        expect(result, isNot(contains('N')));
      });

      test('should format scheduled date with time', () {
        final task = Task(
          'Task with date and time',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 11, 3, 19, 0, 0),
          scheduledTime: true,
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('scheduled: 2025-11-03N19:00:00'));
      });

      test('should format scheduled date with different time values', () {
        final task = Task(
          'Task with specific time',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2024, 12, 25, 8, 30, 45),
          scheduledTime: true,
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('scheduled: 2024-12-25N08:30:45'));
      });

      test('should format scheduled date with midnight time', () {
        final task = Task(
          'Task at midnight',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 1, 1, 0, 0, 0),
          scheduledTime: true,
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('scheduled: 2025-01-01N00:00:00'));
      });

      test('should format scheduled date with end of day time', () {
        final task = Task(
          'Task at end of day',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: DateTime(2025, 6, 15, 23, 59, 59),
          scheduledTime: true,
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('scheduled: 2025-06-15N23:59:59'));
      });

      test('should handle null scheduled date', () {
        final task = Task(
          'Task without scheduled date',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 1, 1),
          scheduled: null,
          scheduledTime: false,
        );

        final result = saver.toTaskNoteString(task);

        expect(result, contains('scheduled: '));
        // Should have empty value after "scheduled: "
        expect(result, contains(RegExp(r'scheduled: \s*\n')));
      });
    });

    group('Round-trip Compatibility', () {
      test('should create content that can be parsed by TaskNoteParser', () {
        final task = Task(
          'Test task #work #urgent',
          status: TaskStatus.todo,
          priority: TaskPriority.high,
          created: DateTime(2025, 8, 16, 22, 33, 28),
          scheduled: DateTime(2025, 8, 16),
        );

        final result = saver.toTaskNoteString(task);

        // Verify it has all required fields for parser
        expect(result, contains(RegExp(r'^---', multiLine: true)));
        expect(result, contains(RegExp(r'^status: \w+', multiLine: true)));
        expect(result, contains(RegExp(r'^priority: \w+', multiLine: true)));
        expect(
            result,
            contains(
                RegExp(r'^scheduled: \d{4}-\d{2}-\d{2}', multiLine: true)));
        expect(
            result,
            contains(
                RegExp(r'^dateCreated: \d{4}-\d{2}-\d{2}T', multiLine: true)));
        expect(
            result,
            contains(
                RegExp(r'^dateModified: \d{4}-\d{2}-\d{2}T', multiLine: true)));
        expect(result, contains(RegExp(r'^tags:', multiLine: true)));
      });

      test('should preserve scheduled time in round-trip', () {
        final task = Task(
          'Task with time',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 11, 3, 10, 0, 0),
          scheduled: DateTime(2025, 11, 3, 19, 30, 45),
          scheduledTime: true,
        );

        final savedContent = saver.toTaskNoteString(task);

        // Verify the saved format includes time
        expect(savedContent, contains('scheduled: 2025-11-03N19:30:45'));
        expect(savedContent, contains('---'));
        expect(savedContent, contains('Task with time'));
      });

      test('should preserve date-only format in round-trip', () {
        final task = Task(
          'Task without time',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          created: DateTime(2025, 11, 3, 10, 0, 0),
          scheduled: DateTime(2025, 11, 3),
          scheduledTime: false,
        );

        final savedContent = saver.toTaskNoteString(task);

        // Verify the saved format does not include time
        expect(savedContent, contains('scheduled: 2025-11-03'));
        expect(savedContent, isNot(contains('N')));
        expect(savedContent, contains('Task without time'));
      });
    });
  });
}
