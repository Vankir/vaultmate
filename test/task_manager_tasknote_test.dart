import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:path/path.dart' as p;
import 'in_memory_tasks_file_storage.dart';

void main() {
  group('TaskManager TaskNote tests', () {
    test('test TaskNote loading from directory', () async {
      final fileContent = '''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

this is content of the task
''';
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/TaskNote/buy groccery.md')
          .writeAsString(fileContent);
      await storage
          .getFile('/TaskNote/tasknote2.md')
          .writeAsString(fileContent);
      final directory = p.dirname('/TaskNote/');
      try {
        var manager =
            TaskManager(storage, todoOnly: true, forDateOnly: DateTime.now());
        await manager.loadTasks(directory);
        expect(manager.tasks.length, equals(2));
        expect(manager.tasks[0].status, equals(TaskStatus.todo));
        expect(manager.tasks[0].tags, equals(['task']));
        expect(manager.tasks[0].description,
            equals('this is content of the task'));
      } finally {}
    });

    test(
        'test that not every file with YAML front matter is considered as TaskNote',
        () async {
      final fileContent = '''---
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
---

this is content of the task
''';
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/TaskNote/buy groccery.md')
          .writeAsString(fileContent);
      await storage
          .getFile('/TaskNote/tasknote2.md')
          .writeAsString(fileContent);
      final directory = p.dirname('/TaskNote/');
      try {
        var manager =
            TaskManager(storage, todoOnly: true, forDateOnly: DateTime.now());
        await manager.loadTasks(directory);
        expect(manager.tasks.length, 0);
      } finally {}
    });

    test('test TaskNote with different statuses', () async {
      var storage = InMemoryTasksFileStorage();

      await storage.getFile('/TaskNote/todo.md').writeAsString('''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

todo task content
''');

      await storage.getFile('/TaskNote/done.md').writeAsString('''---
status: done
priority: high
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
  - completed
---

done task content
''');

      await storage.getFile('/TaskNote/inprogress.md').writeAsString('''---
status: in-progress
priority: medium
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
  - wip
---

in progress task content
''');

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/TaskNote/'));

      expect(manager.tasks.length, equals(3));

      // Find tasks by description
      var todoTask =
          manager.tasks.firstWhere((t) => t.description == 'todo task content');
      var doneTask =
          manager.tasks.firstWhere((t) => t.description == 'done task content');
      var inProgressTask = manager.tasks
          .firstWhere((t) => t.description == 'in progress task content');

      expect(todoTask.status, equals(TaskStatus.todo));
      expect(todoTask.priority, equals(TaskPriority.normal));
      expect(todoTask.tags, equals(['task']));

      expect(doneTask.status,
          equals(TaskStatus.done)); // 'done' maps to todo per parser
      expect(doneTask.priority, equals(TaskPriority.high));
      expect(doneTask.tags, equals(['task', 'completed']));

      expect(inProgressTask.status, equals(TaskStatus.inprogress));
      expect(inProgressTask.priority, equals(TaskPriority.medium));
      expect(inProgressTask.tags, equals(['task', 'wip']));
    });

    test('test TaskNote with multiple tags', () async {
      var storage = InMemoryTasksFileStorage();

      await storage.getFile('/TaskNote/multitag.md').writeAsString('''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
  - work
  - urgent
  - project
  - meeting
---

task with multiple tags
''');

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/TaskNote/'));

      expect(manager.tasks.length, equals(1));
      expect(manager.tasks[0].tags,
          equals(['task', 'work', 'urgent', 'project', 'meeting']));
      expect(manager.tasks[0].description, equals('task with multiple tags'));
    });

    test('test TaskNote with multiline content', () async {
      var storage = InMemoryTasksFileStorage();

      await storage.getFile('/TaskNote/multiline.md').writeAsString('''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

# Task Title

This is a multiline task with **markdown** formatting.

- Item 1
- Item 2

Some more content here.
''');

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/TaskNote/'));

      expect(manager.tasks.length, equals(1));
      expect(manager.tasks[0].description, contains('# Task Title'));
      expect(manager.tasks[0].description, contains('**markdown**'));
      expect(manager.tasks[0].description, contains('- Item 1'));
    });

    test('test TaskNote saving updates status', () async {
      var storage = InMemoryTasksFileStorage();

      await storage.getFile('/TaskNote/update.md').writeAsString('''---
status: open
priority: normal
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

task to be updated
''');

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/TaskNote/'));

      expect(manager.tasks.length, equals(1));
      expect(manager.tasks[0].status, equals(TaskStatus.todo));

      // Update status to done
      await manager.setStatus(manager.tasks[0], TaskStatus.done);

      // Reload and verify
      await manager.loadTasks(p.dirname('/TaskNote/'));
      expect(manager.tasks[0].status, equals(TaskStatus.done));

      // Verify file was updated
      var fileContent =
          await storage.getFile('/TaskNote/update.md').readAsString();
      expect(fileContent, contains('status: done'));
    });

    test('test TaskNote with empty tags list', () async {
      var storage = InMemoryTasksFileStorage();

      await storage.getFile('/TaskNote/notags.md').writeAsString('''---
status: open
priority: low
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

task without tags
''');

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/TaskNote/'));

      expect(manager.tasks.length, equals(1));
      expect(manager.tasks[0].tags, equals(['task']));
      expect(manager.tasks[0].description, equals('task without tags'));
    });

    test('test TaskNote with all priority levels', () async {
      var storage = InMemoryTasksFileStorage();

      final priorities = [
        'lowest',
        'low',
        'normal',
        'medium',
        'high',
        'highest'
      ];
      final expectedPriorities = [
        TaskPriority.lowest,
        TaskPriority.low,
        TaskPriority.normal,
        TaskPriority.medium,
        TaskPriority.high,
        TaskPriority.highest,
      ];

      for (var i = 0; i < priorities.length; i++) {
        await storage
            .getFile('/TaskNote/priority_${priorities[i]}.md')
            .writeAsString('''---
status: open
priority: ${priorities[i]}
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

task with ${priorities[i]} priority
''');
      }

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/TaskNote/'));

      expect(manager.tasks.length, equals(6));

      for (var i = 0; i < priorities.length; i++) {
        var task = manager.tasks.firstWhere(
            (t) => t.description == 'task with ${priorities[i]} priority');
        expect(task.priority, equals(expectedPriorities[i]));
      }
    });

    test('test mixed TaskNote and regular markdown tasks', () async {
      var storage = InMemoryTasksFileStorage();

      // TaskNote file
      await storage.getFile('/mixed/tasknote.md').writeAsString('''---
status: open
priority: high
scheduled: 2025-08-16
dateCreated: 2025-08-16T22:33:28.696+02:00
dateModified: 2025-08-16T22:33:28.696+02:00
tags:
  - task
---

this is a tasknote
''');

      // Regular markdown file with tasks
      await storage.getFile('/mixed/regular.md').writeAsString('''
- [ ] regular task 1 #regular
- [x] regular task 2 #regular
- [ ] regular task 3 #regular
''');

      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/mixed/'));

      expect(manager.tasks.length, equals(4));

      // Verify TaskNote task
      var taskNoteTask = manager.tasks
          .firstWhere((t) => t.description == 'this is a tasknote');
      expect(taskNoteTask.tags, equals(['task']));
      expect(taskNoteTask.priority, equals(TaskPriority.high));

      // Verify regular tasks
      var regularTasks =
          manager.tasks.where((t) => t.tags.contains('regular')).toList();
      expect(regularTasks.length, equals(3));
    });
  });
}
