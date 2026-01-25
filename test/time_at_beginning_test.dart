import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_parser.dart';

void main() {
  group('Time at beginning parsing tests', () {
    test('Parse HH:MM at beginning of task', () {
      var taskString = "- [ ] 10:30 Meeting with team ⏳ 2024-04-08";
      var task = TaskParser().build(taskString);
      
      expect(task.description, equals('Meeting with team'));
      expect(task.scheduled, isNotNull);
      expect(task.scheduled!.hour, equals(10));
      expect(task.scheduled!.minute, equals(30));
      expect(task.scheduledTime, equals(true));
    });

    test('Parse HH:MM at beginning without scheduled date', () {
      var taskString = "- [ ] 14:45 Call doctor";
      var task = TaskParser().build(taskString);
      
      // Without a scheduled date, time should not be applied
      expect(task.description, equals('Call doctor'));
      expect(task.scheduled, isNull);
    });

    test('Parse HH:MM at beginning with priority', () {
      var taskString = "- [ ] 09:00 Important task ⏳ 2024-04-08 ⏫";
      var task = TaskParser().build(taskString);
      
      expect(task.description, equals('Important task'));
      expect(task.scheduled!.hour, equals(9));
      expect(task.scheduled!.minute, equals(0));
      expect(task.priority, equals(TaskPriority.high));
      expect(task.scheduledTime, equals(true));
    });

    test('(@HH:MM) format takes precedence over beginning format', () {
      var taskString = "- [ ] 10:30 Meeting (@14:00) ⏳ 2024-04-08";
      var task = TaskParser().build(taskString);
      
      // (@HH:MM) format should take precedence
      expect(task.scheduled!.hour, equals(14));
      expect(task.scheduled!.minute, equals(0));
      expect(task.scheduledTime, equals(true));
    });

    test('Parse early morning time 00:00', () {
      var taskString = "- [ ] 00:00 Midnight task ⏳ 2024-04-08";
      var task = TaskParser().build(taskString);
      
      expect(task.description, equals('Midnight task'));
      expect(task.scheduled!.hour, equals(0));
      expect(task.scheduled!.minute, equals(0));
      expect(task.scheduledTime, equals(true));
    });

    test('Parse late night time 23:59', () {
      var taskString = "- [ ] 23:59 End of day task ⏳ 2024-04-08";
      var task = TaskParser().build(taskString);
      
      expect(task.description, equals('End of day task'));
      expect(task.scheduled!.hour, equals(23));
      expect(task.scheduled!.minute, equals(59));
      expect(task.scheduledTime, equals(true));
    });

    test('Invalid time format should not be parsed', () {
      var taskString = "- [ ] 25:00 Invalid time ⏳ 2024-04-08";
      var task = TaskParser().build(taskString);
      
      // Invalid time should be kept in description
      expect(task.description, contains('25:00'));
    });

    test('Time without space after should not be parsed', () {
      var taskString = "- [ ] 10:30Meeting ⏳ 2024-04-08";
      var task = TaskParser().build(taskString);
      
      // Should keep as description since no space after time
      expect(task.description, contains('10:30Meeting'));
    });
  });
}
