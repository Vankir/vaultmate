// This is an example unit test.
//
// A unit test tests a single function, method, or class. To learn more about
// writing unit tests, visit
// https://flutter.dev/docs/cookbook/testing/unit/introduction

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:obsi/src/core/tasks/parsers/parser.dart';
import 'package:obsi/src/core/tasks/savers/task_saver.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_parser.dart';

import 'in_memory_tasks_file_storage.dart';

void main() {
  group('task saver tests', () {
    test("TaskParser.toTaskString: task serialize/deserialize", () {
      var created = DateTime.now();
      var dateString = DateFormat("yyyy-MM-dd").format(created);
      var timeString = DateFormat("HH:mm").format(created);
      var scheduled = created;
      var due = created;
      var canceled = created;
      var task = Task("Test",
          created: created,
          scheduled: scheduled,
          due: due,
          cancelled: canceled,
          status: TaskStatus.todo,
          priority: TaskPriority.high,
          scheduledTime: true,
          recurranceRule: "every day");
      var serializedTask = TaskParser().toTaskString(task);
      print("Serialized task: $serializedTask");
      expect(
          serializedTask,
          equals(
              "- [ ] Test (@$timeString)⏫ ➕ $dateString ❌ $dateString 📅 $dateString ⏳ $dateString 🔁 every day"));

      var builtTask = TaskParser().build(serializedTask);
      var newSerializedTask = TaskParser().toTaskString(builtTask);

      expect(serializedTask, equals(newSerializedTask));
    });

    test("TaskParser: task serialize/deserialize", () {
      var task = Task("""this is test for 
      multiline description""",
          created: DateTime.now(),
          status: TaskStatus.todo,
          priority: TaskPriority.normal);
      var serializedTask = TaskParser().toTaskString(task);
      var newTask = TaskParser().build(serializedTask);
      expect(newTask.description, equals(task.description));
    });

    test("TaskParser: recurrence rules", () {
      var taskStrings = [
        "- [ ] test ⏳ 2025-03-14 🔁 every day",
        "- [ ] test 🔁 every day ⏳ 2025-03-14",
        "- [ ] test 🔁every day⏳ 2025-03-14",
      ];

      var tasks = taskStrings.map((taskString) {
        return TaskParser().build(taskString);
      });

      expect(tasks.length, equals(3));
      for (var task in tasks) {
        expect(task.recurrenceRule, equals("every day"));
        expect(task.description, equals("test"));
      }
    });

    test("TaskParser: set scheduled time for notifications", () {
      var task = Task("""this is test for 
      multiline description""",
          created: DateTime.now(),
          scheduled: DateTime.now(),
          status: TaskStatus.todo,
          priority: TaskPriority.normal);
      task.scheduledTime = true;
      var serializedTask = TaskParser().toTaskString(task);
      var newTask = TaskParser().build(serializedTask);
      expect(newTask.scheduledTime, equals(true));
    });

    test("TaskParser.toTaskString: dataview format serialization", () {
      final task = Task('Dataview task',
          status: TaskStatus.todo,
          priority: TaskPriority.high,
          created: DateTime(2024, 4, 6),
          due: DateTime(2024, 4, 7),
          scheduled: DateTime(2024, 4, 8, 10, 20),
          scheduledTime: true,
          recurranceRule: 'every day');

      final serialized =
          TaskParser().toTaskString(task, dataViewDefaultMarkdownFormat: true);

      expect(serialized, contains('[created:: 2024-04-06]'));
      expect(serialized, contains('[due:: 2024-04-07]'));
      expect(serialized, contains('[scheduled:: 2024-04-08T10:20:00]'));
      expect(serialized, contains('[priority:: high]'));
      expect(serialized, contains('[repeat:: every day]'));
      expect(serialized, isNot(contains('📅')));
      expect(serialized, isNot(contains('⏫')));
      expect(serialized, isNot(contains('🔁')));
    });

    test("TaskParser.toTaskString: dataview scheduled without time", () {
      final task = Task('Date only schedule',
          status: TaskStatus.todo,
          scheduled: DateTime(2024, 6, 1),
          scheduledTime: false);

      final serialized =
          TaskParser().toTaskString(task, dataViewDefaultMarkdownFormat: true);

      expect(serialized, contains('[scheduled:: 2024-06-01]'));
      expect(serialized, isNot(contains('T00:00:00')));
    });

    test("TaskParser.toTaskString: dataview omits normal and empty metadata",
        () {
      final task = Task('Minimal dataview task',
          status: TaskStatus.todo,
          priority: TaskPriority.normal,
          recurranceRule: '');

      final serialized =
          TaskParser().toTaskString(task, dataViewDefaultMarkdownFormat: true);

      expect(serialized, isNot(contains('[priority::')));
      expect(serialized, isNot(contains('[repeat::')));
    });

    test("TaskParser: dataview roundtrip normalizes to bracket syntax", () {
      const source =
          '- [ ] Normalize me (due:: 2024-07-10), (priority:: highest)';

      final parsed = TaskParser().build(source);
      final serialized = TaskParser()
          .toTaskString(parsed, dataViewDefaultMarkdownFormat: true);

      expect(serialized, contains('[due:: 2024-07-10]'));
      expect(serialized, contains('[priority:: highest]'));
      expect(serialized, isNot(contains('(due::')));
      expect(serialized, isNot(contains('(priority::')));
    });

    test('change task status in file', () async {
      var fileStorage = InMemoryTasksFileStorage();
      await fileStorage
          .getFile('test.md')
          .writeAsString('''**Header of test note**

- [ ] this is a test task
this is some text which should be skipped
- [x] this is done task
- this is not a task, just list item
- [ ] not done task
- [ ] task with priority, created and due dates 📅 2024-04-07 🔼 ➕ 2024-04-06 
##This is header
some text could be here
''');
      var tasks = await Parser.readTasks(fileStorage.getFile('test.md'));

      Task testTask = tasks[0];
      var initialStatus = testTask.status;
      var newStatus =
          initialStatus == TaskStatus.todo ? TaskStatus.done : TaskStatus.todo;

      testTask.status = newStatus;
      await TaskSaver(fileStorage).saveTasks([testTask]);

      var changedTasks = await Parser.readTasks(fileStorage.getFile('test.md'));
      expect(changedTasks[0].status, equals(newStatus));
    });

    test('read tasks and re-save 1 task without changes', () async {
      var fileStorage = InMemoryTasksFileStorage();
      var content = '''📅
- [ ] task1
- [ ] task2 📅 2024-04-27📅1234
- [x] task3       
- [ ] task4 🔁 every day
- [ ] task5
''';
      await fileStorage.getFile('test.md').writeAsString(content);

      var tasks = await Parser.readTasks(fileStorage.getFile('test.md'));

      Task testTask1 = tasks[0];
      await TaskSaver(fileStorage).saveTasks([testTask1]);

      var readContent = await fileStorage.getFile('test.md').readAsString();
      //await testFile.remove();
      //conent of the original and re-saved files should be the same
      expect(readContent, equals(content));
    });

    test('read tasks and re-save 1 task with some changes', () async {
      var fileStorage = InMemoryTasksFileStorage();
      await fileStorage
          .getFile('test.md')
          .writeAsString('''📅 This is file content
- [ ] task1
- [ ] task2 📅 2024-04-27📅1234
- [x] task3  🔁 every day📅 2024-04-07     
- [ ] task4
##This is another content in the file
and it is multiline and contains some
[[links]]
- [ ] task5

**Bold test** can be in the file as well
as some other text
''');
      var tasks = await Parser.readTasks(fileStorage.getFile('test.md'));

      //create today date without time
      var today =
          DateTime.parse(DateFormat("yyyy-MM-dd").format(DateTime.now()));

      Task testTask2 = tasks[2];
      testTask2.scheduled = DateTime.now();
      await TaskSaver(fileStorage).saveTasks([testTask2]);

      var updatedTasks = await Parser.readTasks(fileStorage.getFile('test.md'));
      expect(updatedTasks[2].scheduled, equals(today));
      expect(tasks.length, equals(updatedTasks.length));
    });
  });
}
