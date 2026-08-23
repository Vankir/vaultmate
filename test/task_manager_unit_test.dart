// This is an example unit test.
//
// A unit test tests a single function, method, or class. To learn more about
// writing unit tests, visit
// https://flutter.dev/docs/cookbook/testing/unit/introduction

import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/parsers/parser.dart';
import 'in_memory_tasks_file_storage.dart';
import 'package:obsi/src/core/tasks/reccurent_task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_parser.dart';
import 'package:path/path.dart' as p;

void main() {
  group('TaskParser tests', () {
    test('task priorities', () {
      var tasksWithPriorities = {
        "- [x] task with priority, created and due dates #urgent 📅 2024-04-07 ⏬ ➕ 2024-04-06 ":
            TaskPriority.lowest,
        "- [ ] task with priority, created and due dates #personal 📅 2024-04-07 🔽 ➕ 2024-04-06 ":
            TaskPriority.low,
        "- [ ] task with priority, created and due dates #project 📅 2024-04-07 ➕ 2024-04-06 ":
            TaskPriority.normal,
        "- [ ] task with priority, created and due dates #review 📅 2024-04-07 🔼 ➕ 2024-04-06 ":
            TaskPriority.medium,
        "- [ ] task with priority, created and due dates #important  📅 2024-04-07 ⏫ ➕ 2024-04-06 ":
            TaskPriority.high,
        "- [ ] task with priority, created and due dates #critical 📅 2024-04-07 🔺 ➕ 2024-04-06 ":
            TaskPriority.highest
      };
      tasksWithPriorities.forEach((key, value) {
        Task task = TaskParser().build(key);
        expect(task.priority, value);
        // Verify tags are properly parsed
        expect(task.tags.length, equals(1));
      });
    });

    test('task created date', () {
      var tasksWithPriorities = {
        // this test case doesn't work...
        //"- [/] task with priority, created and due dates #test 📅 2024-04-07 ⏬ ➕     2024":
        //    DateTime(2024),
        "- [/] task with priority, created and due dates #test #work 📅 2024-04-07 ⏬ ➕ 2024-04-06":
            DateTime(2024, 04, 06),
        "- [/] task with priority, created and due dates #personal 📅 2024-04-07 🔽 ":
            null,
        "- [/] task with priority, created and due dates #project 📅 2024-04-07 ⏬ ➕":
            null,
        "- [/] task with priority, created and due dates #meeting 📅 2024-04-07 ⏬ ➕     ":
            null,
        "- [/] task with priority, created and due dates #urgent 📅 2024-04-07 ⏬ ➕2024-12-06":
            DateTime(2024, 12, 06),
        "- [/] task with priority, created and due dates #review #important 📅 2024-04-07 ⏬ ➕ 2024-09-15 lks;kdfksdk;":
            DateTime(2024, 09, 15),
      };
      tasksWithPriorities.forEach((key, value) {
        Task task = TaskParser().build(key);
        expect(task.created, value);
        // Verify tags are properly parsed
        expect(task.tags.isNotEmpty, true);
      });
    });

    test('task statuses', () {
      var tasksWithStatuses = {
        "- [ ] task with priority, created and due dates #todo #work 📅 2024-04-07 ⏬ ➕ 2024-04-06 ":
            TaskStatus.todo,
        "- [x] task with priority, created and due dates #done #project 📅 2024-04-07 🔽 ➕ 2024-04-06 ":
            TaskStatus.done,
        "- [/] task with priority, created and due dates #inprogress #meeting 📅 2024-04-07 ➕ 2024-04-06 ":
            TaskStatus.inprogress,
        "- [-] task with priority, created and due dates #cancelled #review 📅 2024-04-07 🔼 ➕ 2024-04-06 ":
            TaskStatus.cancelled,
      };
      tasksWithStatuses.forEach((key, value) {
        Task task = TaskParser().build(key);
        expect(task.status, value);
        expect(task.description, "task with priority, created and due dates");
        // Verify tags are properly parsed and separated from description
        expect(task.tags.isNotEmpty, true);
        expect(task.tags.length, 2); // Each test case has 2 tags
      });
    });

    test('task tags parsing and extraction', () {
      var tasksWithTags = {
        "- [ ] simple task with single tag #work": {
          'description': 'simple task with single tag',
          'tags': ['work']
        },
        "- [x] task with multiple tags #urgent #project #meeting": {
          'description': 'task with multiple tags',
          'tags': ['urgent', 'project', 'meeting']
        },
        "- [/] task #personal with tags in middle #important of description": {
          'description': 'task with tags in middle of description',
          'tags': ['personal', 'important']
        },
        "- [-] task with mixed content #review 📅 2024-04-07 #deadline ⏫ ➕ 2024-04-06":
            {
          'description': 'task with mixed content',
          'tags': ['review', 'deadline']
        },
        "- [ ] task with no tags at all": {
          'description': 'task with no tags at all',
          'tags': <String>[]
        },
        "- [ ] task with #duplicate #duplicate #unique tags": {
          'description': 'task with tags',
          'tags': ['duplicate', 'unique'] // duplicates should be removed
        },
        "- [ ] task with #camelCase #snake_case #123numbers tags": {
          'description': 'task with tags',
          'tags': ['camelCase', 'snake_case', '123numbers']
        }
      };

      tasksWithTags.forEach((taskString, expected) {
        Task task = TaskParser().build(taskString);
        expect(task.description, expected['description']);
        expect(task.tags, expected['tags']);

        // Verify description doesn't contain hashtags
        expect(task.description!.contains('#'), false,
            reason: 'Description should not contain hashtags after parsing');
      });
    });

    test('test all dates', () {
      var test =
          "- [ ] test with dates #important #project 🔺 ➕ 2024-04-06 🛫 2024-04-07 ⏳ 2024-04-08 📅 2024-04-09 ❌ 2024-04-10 ✅ 2024-04-11";
      Task task = TaskParser().build(test);
      expect(task.description, equals("test with dates"));
      expect(task.tags, equals(["important", "project"]));
      expect(task.priority, equals(TaskPriority.highest));
    });

    test('test scheduled date and time', () {
      var tests = [
        "- [ ] test0 ⏳ 2024-04-08 10:20",
        "- [ ] test1 (@10:20) 📅 2024-04-07 ⏳ 2024-04-08",
        "- [ ] test2 (@11:21) ⏳ 2024-04-08 10:20 📅 2024-04-07 ",
        "- [ ] test3 (@2024-11-12 10:20) ⏳ 2024-04-08 📅 2024-04-07 ",
        "- [ ] test4 (@2024-04-08 10:20) 📅 2024-04-07 ",
        "- [ ] test5 (@10:20) 📅 2024-04-07 ",
        "- [ ] test6 ⏳ 2024-04-08📅 2024-04-07 ",
        "- [ ] test7 ⏳ 2024-04-08  📅 2024-04-07 ",
      ];
      var tasks = tests.map((element) => TaskParser().build(element)).toList();
      for (var i = 0; i < 5; i++) {
        print(tasks[i].toString());
        expect(tasks[i].scheduled?.hour, equals(10));
        expect(tasks[i].scheduled?.minute, equals(20));
        expect(tasks[i].scheduled?.year, equals(2024));
        expect(tasks[i].scheduled?.month, equals(04));
        expect(tasks[i].scheduled?.day, equals(08));
        // schedule time is set two ways but only one is used (in Tasks plugin format)
        if (i == 2) {
          expect(tasks[i].description, equals('test2 (@11:21)'));
        } else {
          expect(tasks[i].description, equals('test$i'));
        }
        expect(tasks[i].scheduledTime, true);
      }

      expect(tasks[5].scheduled, null);
      expect(tasks[5].scheduledTime, false);

      for (var i = 6; i < tasks.length; i++) {
        print(tasks[i].toString());
        expect(tasks[i].scheduled?.hour, equals(0));
        expect(tasks[i].scheduled?.minute, equals(0));
        expect(tasks[i].description, equals('test$i'));
        expect(tasks[i].scheduledTime, false);
      }
    });

    test('create task', () {
      Task task = TaskParser().build(
          "- [/] task with priority, created and due dates 📅 2024-04-07 🔼 ➕ 2024-04-06 ");
      expect(task.status, equals(TaskStatus.inprogress));
      expect(task.priority, equals(TaskPriority.medium));
      //expect(task.created, equals(expected));
      //expect(task., matcher)
    });

    test('should parse 4 tasks where 1 - done and 3 are not done', () async {
      var fileStorage = InMemoryTasksFileStorage();
      await fileStorage
          .getFile('test.md')
          .writeAsString('''**Header of test note**

- [ ] this is a test task #personal
this is some text which should be skipped
- [x] this is done task #work #completed
- this is not a task, just list item
- [ ] not done task #project #urgent
- [ ] task with priority, created and due dates #important 📅 2024-04-07 🔼 ➕ 2024-04-06 
##This is header
some text could be here
''');

      var tasks = await Parser.readTasks(fileStorage.getFile('test.md'));
      expect(tasks.length, equals(4));
      expect(tasks[0].description, equals("this is a test task"));
      expect(tasks[0].status, equals(TaskStatus.todo));
      expect(tasks[0].tags, equals(["personal"]));
      expect(tasks[1].status, equals(TaskStatus.done));
      expect(tasks[1].tags, equals(["work", "completed"]));
      expect(tasks[2].status, equals(TaskStatus.todo));
      expect(tasks[2].tags, equals(["project", "urgent"]));
      expect(tasks[3].status, equals(TaskStatus.todo));
      expect(tasks[3].tags, equals(["important"]));
    });

    test('loading task with subtasks - bug', () async {
      var fileStorage = InMemoryTasksFileStorage();
      await fileStorage
          .getFile('test.md')
          .writeAsString('''**Header of test note**

- [x] main task
	- [ ] subtask 1
	- [ ] subtask 2
	- [ ] subtask 3
  
##This is header
some text could be here
''');

      var tasks = await Parser.readTasks(fileStorage.getFile('test.md'));

      expect(tasks.length, equals(4));
      expect(tasks[2].description, equals("subtask 2"));
      expect(tasks[3].description, equals("subtask 3"));
      expect(tasks[1].description, equals("subtask 1"));
      expect(tasks[0].description, equals("main task"));
    });
  });

  test('error in parsing', () async {
    var fileStorage = InMemoryTasksFileStorage();
    await fileStorage
        .getFile('test.md')
        .writeAsString("""**Header of test note**

- [ ] this is a test task
- [ ] test1 📅 2024-04-26
- [ ] not done tasksk
- [ ] task with priority, created and due dates 📅 2024-04-07 🔼 ➕ 2024-04-06
- [ ] last task
##This is header
some text could be here""");

    var tasks = await Parser.readTasks(fileStorage.getFile('test.md'));
    expect(tasks[1].description, equals("test1"));
  });

  group('task manager', () {
    test('test loading', () async {
      var fileStorage = InMemoryTasksFileStorage();
      await fileStorage
          .getFile('/test.md')
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

      var manager = TaskManager(fileStorage);
      await manager.loadTasks(p.dirname('/test.md'));
      expect(manager.tasks.length, equals(4));
      await manager.setStatus(manager.tasks[0], TaskStatus.done);
      await manager.loadTasks(p.dirname('/test.md'));
      expect(manager.tasks.length, equals(4));
    });

    test('test loading from directory', () async {
      final fileContent = '''**Header of test note**

- [ ] this is a test task
this is some text which should be skipped
- [x] this is done task
- this is not a task, just list item
- [ ] not done task
- [ ] task with priority, created and due dates 📅 2024-04-07 🔼 ➕ 2024-04-06 
##This is header
some text could be here
''';
      var storage = InMemoryTasksFileStorage();
      await storage.getFile('/test1.md').writeAsString(fileContent);
      await storage.getFile('/test2.md').writeAsString(fileContent);
      final directory = p.dirname('/');
      try {
        var manager =
            TaskManager(storage, todoOnly: true, forDateOnly: DateTime.now());
        await manager.loadTasks(directory);
        expect(manager.tasks.length, equals(6));
        manager.tasks[5].done = DateTime.now();
        await manager.setStatus(manager.tasks[5], TaskStatus.done);
        await manager.loadTasks(directory);
        expect(manager.tasks.length, equals(6));
        expect(manager.tasks[5].status, equals(TaskStatus.done));
      } finally {}
    });

    test('test bug with task saving', () async {
      final fileContent = '''**Header of test note**

- [ ] 123456 7890 📅 2024-04-07 🔼 ➕ 2024-04-06
##This is header
some text could be here
''';
      var storage = InMemoryTasksFileStorage();

      await storage.getFile('/test.md').writeAsString(fileContent);
      final directory = p.dirname('/test.md');

      var manager =
          TaskManager(storage, todoOnly: true, forDateOnly: DateTime.now());
      await manager.loadTasks(directory);
      manager.tasks[0].done = DateTime.now();
      await manager.setStatus(manager.tasks[0], TaskStatus.done);
      await manager.loadTasks(directory);
      expect(manager.tasks.length, equals(1));
      expect(manager.tasks[0].status, equals(TaskStatus.done));
      expect(manager.tasks[0].description, equals("123456 7890"));
    });

    test('getting vault name', () async {
//       var fileStorage = InMemoryTasksFileStorage();
//       await fileStorage
//           .getFile('/test_resources/test.md')
//           .writeAsString('''**Header of test note**

// - [ ] this is a test task
// this is some text which should be skipped
// - [x] this is done task
// - this is not a task, just list item
// - [ ] not done task #task
// - [ ] #task task with priority, created and due dates 📅 2024-04-07 🔼 ➕ 2024-04-06
// ##This is header
// some text could be here
// ''');

//       await fileStorage
//           .getFile('/test_resources/.obsidian')
//           .writeAsString('''he-he''');
//       // var obsidianDirectory =
//       //     Directory(p.join(p.dirname('/test.md'), '.obsidian'));
//       // await obsidianDirectory.create();
//       var manager = TaskManager(fileStorage);
//       await manager.loadTasks(p.dirname('/test.md'));

//       expect(manager.vaultName, equals('test_resources'));
      // await obsidianDirectory.delete(recursive: true);
    });

    test('test loading with filtering', () async {
      var storage = InMemoryTasksFileStorage();
      await storage.getFile('/test.md').writeAsString('''**Header of test note**

- [ ] this is a test task
this is some text which should be skipped
- [x] this is done task
- this is not a task, just list item
- [ ] not done task #task
- [ ] #task task with priority, created and due dates 📅 2024-04-07 🔼 ➕ 2024-04-06 
##This is header
some text could be here
''');

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'), taskFilter: "#task");
      var tasks = manager.tasks;
      expect(tasks.length, equals(2));
      expect(tasks[0].description, equals("not done task"));
      expect(tasks[1].description,
          equals("task with priority, created and due dates"));
    });

    test('Test done for recurring task', () async {
      var storage = InMemoryTasksFileStorage();

      await storage.getFile('/test.md').writeAsString('''
- [ ] this is a test task
- [x] this is done task1 ✅ 2024-10-10
- [x] this is done task2 ✅ 2024-10-11
- [x] this is done task3 ✅ 2022-10-11
- this is not a task, just list item
- [ ] not done task ⏳ 2024-10-11 🔁every day
- [ ] task with priority, created and due dates 📅 2024-04-07 🔼 ➕ 2024-04-06 
##This is header
some text could be here
''');

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'));
      expect(manager.tasks.length, equals(6));

      await manager.setStatus(manager.tasks[4], TaskStatus.done);

      expect(manager.tasks[4].status, equals(TaskStatus.todo));
      expect(manager.tasks[5].status, equals(TaskStatus.done));
      expect(manager.tasks.length, equals(7));
    });

    test('create task in file', () async {
      var storage = InMemoryTasksFileStorage();
      var manager = TaskManager(storage);
      var fileDirectory = "test/test_resources/";
      var testFile = "2remove.md";
      var task = Task("some test task",
          status: TaskStatus.done,
          created: DateTime.now(),
          recurranceRule: "every day");
      var fullFileName = "$fileDirectory$testFile";
      await manager.saveTask(task, filePath: fullFileName);

      await manager.loadTasks(fileDirectory);
      expect(manager.tasks[0].status, equals(TaskStatus.done));
      expect(manager.tasks[0].recurrenceRule, equals("every day"));
    });

    test('create recurent task in file', () async {
      var storage = InMemoryTasksFileStorage();
      var manager = TaskManager(storage);

      await storage.getFile('test.md').writeAsString('**Header of test note**');

      var task = Task("some test task",
          status: TaskStatus.done,
          created: DateTime(2024, 04, 05),
          scheduled: DateTime(2024, 04, 06),
          recurranceRule: "every day");

      await manager.saveTask(task, filePath: 'test.md');

      await manager.loadTasks(p.dirname('test.md'));
      //cache checkes that file has been modified since last load but time is too short in test so either need to disable cache or set delay
      await Future.delayed(Duration(seconds: 1));
      await manager.setStatus(manager.tasks[0], TaskStatus.done);

      expect(manager.tasks.length, equals(2));
      expect(manager.tasks[1].status, equals(TaskStatus.done));
      expect(manager.tasks[1].scheduled, equals(DateTime(2024, 04, 06)));

      expect(manager.tasks[0].status, equals(TaskStatus.todo));
      var today = DateTime.now();
      expect(manager.tasks[0].created,
          equals(DateTime(today.year, today.month, today.day)));
      expect(manager.tasks[0].scheduled, equals(DateTime(2024, 04, 07)));
      expect(manager.tasks[0].recurrenceRule, equals("every day"));
    });
  });

  group('task manager swipe actions', () {
    test('scheduleForTomorrow sets scheduled date to tomorrow and persists',
        () async {
      var storage = InMemoryTasksFileStorage();
      await storage.getFile('/test.md').writeAsString('''**Header**

- [ ] a task to postpone
''');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'));

      await manager.scheduleForTomorrow(manager.tasks[0]);

      var tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(
          TaskManager.sameDate(manager.tasks[0].scheduled, tomorrow), isTrue);

      await manager.loadTasks(p.dirname('/test.md'));
      expect(
          TaskManager.sameDate(manager.tasks[0].scheduled, tomorrow), isTrue);
    });

    test('deleteTask removes only the targeted task and leaves siblings',
        () async {
      var storage = InMemoryTasksFileStorage();
      await storage.getFile('/test.md').writeAsString('''**Header**

- [ ] first task
- [ ] second task to delete
- [ ] third task
''');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'));
      expect(manager.tasks.length, equals(3));

      var taskToDelete =
          manager.tasks.firstWhere((t) => t.description == 'second task to delete');
      await manager.deleteTask(taskToDelete);

      expect(manager.tasks.length, equals(2));
      expect(manager.tasks.any((t) => t.description == 'second task to delete'),
          isFalse);

      await manager.loadTasks(p.dirname('/test.md'));
      expect(manager.tasks.length, equals(2));
      expect(manager.tasks[0].description, equals('first task'));
      expect(manager.tasks[1].description, equals('third task'));

      var content = await storage.getFile('/test.md').readAsString();
      expect(content.contains('second task to delete'), isFalse);
      expect(content, contains('first task'));
      expect(content, contains('third task'));
    });

    test('deleteTask removes an indented task without leaving stray whitespace',
        () async {
      var storage = InMemoryTasksFileStorage();
      await storage.getFile('/test.md').writeAsString(
          '- [ ] parent task\n  - [ ] indented child task\n- [ ] next task\n');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'));

      var child =
          manager.tasks.firstWhere((t) => t.description == 'indented child task');
      await manager.deleteTask(child);

      var content = await storage.getFile('/test.md').readAsString();
      expect(content, equals('- [ ] parent task\n- [ ] next task\n'));
    });

    test(
        'deleteTask on a recurring task removes only the current occurrence and does not create a next one',
        () async {
      var storage = InMemoryTasksFileStorage();
      var manager = TaskManager(storage);

      var task = Task("recurring task to delete",
          status: TaskStatus.todo,
          created: DateTime(2024, 04, 05),
          scheduled: DateTime(2024, 04, 06),
          recurranceRule: "every day");
      await manager.saveTask(task, filePath: 'test.md');
      await manager.loadTasks(p.dirname('test.md'));
      expect(manager.tasks.length, equals(1));

      await manager.deleteTask(manager.tasks[0]);

      expect(manager.tasks.length, equals(0));
      await manager.loadTasks(p.dirname('test.md'));
      expect(manager.tasks.length, equals(0));
    });
  });

  group('nested task actions do not cascade (FR-008, FR-009)', () {
    test('marking a child task done does not change its parent', () async {
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/test.md')
          .writeAsString('- [ ] parent task\n  - [ ] child task\n');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'));

      var parent =
          manager.tasks.firstWhere((t) => t.description == 'parent task');
      var child =
          manager.tasks.firstWhere((t) => t.description == 'child task');
      expect(child.depth, equals(1));
      expect(child.parentTaskId, equals(parent.taskSource!.id));

      await manager.setStatus(child, TaskStatus.done);

      expect(child.status, equals(TaskStatus.done));
      expect(parent.status, equals(TaskStatus.todo));

      await manager.loadTasks(p.dirname('/test.md'));
      expect(
          manager.tasks
              .firstWhere((t) => t.description == 'child task')
              .status,
          equals(TaskStatus.done));
      expect(
          manager.tasks
              .firstWhere((t) => t.description == 'parent task')
              .status,
          equals(TaskStatus.todo));
    });

    test('marking a parent task done does not change its child', () async {
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/test.md')
          .writeAsString('- [ ] parent task\n  - [ ] child task\n');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'));

      var parent =
          manager.tasks.firstWhere((t) => t.description == 'parent task');
      var child =
          manager.tasks.firstWhere((t) => t.description == 'child task');

      await manager.setStatus(parent, TaskStatus.done);

      expect(parent.status, equals(TaskStatus.done));
      expect(child.status, equals(TaskStatus.todo));

      await manager.loadTasks(p.dirname('/test.md'));
      expect(
          manager.tasks
              .firstWhere((t) => t.description == 'parent task')
              .status,
          equals(TaskStatus.done));
      expect(
          manager.tasks
              .firstWhere((t) => t.description == 'child task')
              .status,
          equals(TaskStatus.todo));
    });

    test('deleting a parent task does not remove its children', () async {
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/test.md')
          .writeAsString('- [ ] parent task\n  - [ ] child task\n');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'));

      var parent =
          manager.tasks.firstWhere((t) => t.description == 'parent task');
      await manager.deleteTask(parent);

      var content = await storage.getFile('/test.md').readAsString();
      expect(content.contains('parent task'), isFalse);
      expect(content, contains('child task'));

      await manager.loadTasks(p.dirname('/test.md'));
      expect(manager.tasks.length, equals(1));
      expect(manager.tasks[0].description, equals('child task'));
      // With its parent line gone, the child is now the first (and only)
      // task in the file on reparse - no preceding task to link to, so it
      // resolves to depth 0, matching spec.md's "no preceding task" edge
      // case (same rule as FR-011's "parent absent from view").
      expect(manager.tasks[0].depth, equals(0));
    });

    test('deleting a child task does not remove its parent', () async {
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/test.md')
          .writeAsString('- [ ] parent task\n  - [ ] child task\n');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'));

      var child =
          manager.tasks.firstWhere((t) => t.description == 'child task');
      await manager.deleteTask(child);

      var content = await storage.getFile('/test.md').readAsString();
      expect(content.contains('child task'), isFalse);
      expect(content, contains('parent task'));

      await manager.loadTasks(p.dirname('/test.md'));
      expect(manager.tasks.length, equals(1));
      expect(manager.tasks[0].description, equals('parent task'));
      expect(manager.tasks[0].depth, equals(0));
    });
  });

  group('calculateNextOccurrence', () {
    test('every day', () {
      final result = RecurrentTask.calculateNextOccurrence(
          DateTime(2025, 3, 16), 'every day');
      expect(result, DateTime(2025, 3, 17));
    });

    test('every week', () {
      final result = RecurrentTask.calculateNextOccurrence(
          DateTime(2025, 3, 16), 'every week');
      expect(result, DateTime(2025, 3, 23));
    });

    // test('every 2 weeks', () {
    //   final result = RecurrentTask.calculateNextOccurrence(
    //       DateTime(2025, 3, 16), 'every 2 weeks');
    //   expect(result, DateTime(2025, 3, 30));
    // });

    test('every month', () {
      final result = RecurrentTask.calculateNextOccurrence(
          DateTime(2025, 3, 16), 'every month');
      expect(result, DateTime(2025, 4, 16));
    });

    test('every Monday', () {
      final result = RecurrentTask.calculateNextOccurrence(
          DateTime(2025, 3, 16), 'every Monday');
      expect(result.weekday, DateTime.monday);
    });

    test('every weekday', () {
      final result = RecurrentTask.calculateNextOccurrence(
          DateTime(2025, 3, 15), 'every weekday'); // Saturday
      expect(result.weekday, DateTime.monday);
    });

    test('every year', () {
      final result = RecurrentTask.calculateNextOccurrence(
          DateTime(2025, 3, 16), 'every year');
      expect(result, DateTime(2026, 3, 16));
    });
  });

  group('TaskManager with task filter', () {
    test('loading tasks with filter - should skip tasks without filter tag',
        () async {
      var storage = InMemoryTasksFileStorage();
      await storage.getFile('/test.md').writeAsString('''**Header of test note**

- [ ] task without filter tag
- [ ] task with filter #work
- [ ] another task without filter
- [ ] #work task with filter at start
- [ ] task with #work filter in middle
- [ ] task with multiple #work #personal tags
''');

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'), taskFilter: '#work');
      var tasks = manager.tasks;

      // Should only load tasks that contain the #work tag
      expect(tasks.length, equals(4));
      expect(manager.allTags, isNot(contains('work')));
      expect(tasks[0].description, equals('task with filter'));
      expect(tasks[0].tags, isNot(contains('work')));
      expect(tasks[1].description, equals('task with filter at start'));
      expect(tasks[2].description, equals('task with filter in middle'));
      expect(tasks[3].description, equals('task with multiple tags'));
    });

    test('loaded task descriptions should not contain filter tag', () async {
      var storage = InMemoryTasksFileStorage();
      await storage.getFile('/test.md').writeAsString('''**Header of test note**

- [ ] task with filter #work
- [ ] #work task with filter at start
- [ ] task with #work filter in middle
- [ ] task with multiple #work #personal tags
''');

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'), taskFilter: '#work');
      var tasks = manager.tasks;

      // Task descriptions should not contain the filter tag
      expect(tasks[0].description, equals('task with filter'));
      expect(tasks[1].description, equals('task with filter at start'));
      expect(tasks[2].description, equals('task with filter in middle'));
      expect(tasks[3].description, equals('task with multiple tags'));

      // But tags should still be parsed correctly
      expect(tasks[0].tags, isNot(contains('work')));
      expect(tasks[3].tags, contains('personal'));
    });

    test('saving new task with filter should automatically add filter tag',
        () async {
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/test.md')
          .writeAsString('**Header of test note**\n\n');

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'), taskFilter: '#work');

      // Create and save a new task
      var newTask = Task('new task without filter tag');
      await manager.saveTask(newTask, filePath: '/test.md');
      expect(manager.allTags, isNot(contains('work')));
      // Read the file content to verify filter tag was added
      var fileContent = await storage.getFile('/test.md').readAsString();
      expect(fileContent, contains('new task without filter tag #work'));
    });

    test('saving new task with #tag', () async {
      var task = Task('new task');
      task.description = 'new task #t';
      task.description = 'new task #ta';
      task.description = 'new task #tag';
      expect(task.tags, contains('tag'));
      expect(task.description, 'new task');
      expect(task.tags.length, equals(3));
      // var storage = InMemoryTasksFileStorage();
      // await storage
      //     .getFile('/test.md')
      //     .writeAsString('**Header of test note**\n\n');

      // var manager = TaskManager(storage);
      // await manager.loadTasks(p.dirname('/test.md'));

      // // Create and save a new task
      // var newTask = Task('new task without filter tag');
      // await manager.saveTask(newTask, filePath: '/test.md');
      // expect(manager.allTags, isNot(contains('work')));
      // // Read the file content to verify filter tag was added
      // var fileContent = await storage.getFile('/test.md').readAsString();
      // expect(fileContent, contains('new task without filter tag #work'));
    });
  });
}
