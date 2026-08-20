import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/inbox_tasks/cubit/inbox_tasks_cubit.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/settings/settings_service.dart';
import 'package:path/path.dart' as p;

import '../../../in_memory_tasks_file_storage.dart';

class MockSettingsController extends Mock implements SettingsController {
  @override
  String? get vaultDirectory => '/';

  @override
  String get dateTemplate => 'yyyy-MM-dd';

  @override
  bool get showOverdueOnly => false;

  @override
  SortMode get sortMode => SortMode.none;

  @override
  ViewMode get viewMode => ViewMode.list;

  bool _swipeHintShownToday = false;
  bool _swipeHintShownInbox = false;

  @override
  bool get swipeHintShownToday => _swipeHintShownToday;

  @override
  bool get swipeHintShownInbox => _swipeHintShownInbox;

  @override
  Future<void> updateSwipeHintShownToday(bool value) async {
    _swipeHintShownToday = value;
  }

  @override
  Future<void> updateSwipeHintShownInbox(bool value) async {
    _swipeHintShownInbox = value;
  }
}

void main() {
  setUp(() {
    SettingsController.setInstance(MockSettingsController());
  });

  group('InboxTasksCubit swipe actions', () {
    // Constructed with today: false throughout, purely to avoid this cubit's
    // pre-existing, unrelated today-only notification/widget-sync side
    // effects in tasksChangedListener (which need plugin channels not
    // available in a plain test). None of the methods under test read
    // `today`, so this exercises the same code paths as production.

    test('postponeToTomorrowPressed schedules the task for tomorrow',
        () async {
      var storage = InMemoryTasksFileStorage();
      await storage.getFile('/test.md').writeAsString('''**Header**

- [ ] a task to postpone
''');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'));
      var cubit = InboxTasksCubit(manager, false);
      await Future.delayed(Duration.zero);

      var task = manager.tasks[0];
      cubit.postponeToTomorrowPressed(task);
      await Future.delayed(Duration.zero);

      var tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(TaskManager.sameDate(task.scheduled, tomorrow), isTrue);

      await cubit.close();
    });

    test('deleteTaskPressed removes the task', () async {
      var storage = InMemoryTasksFileStorage();
      await storage.getFile('/test.md').writeAsString('''**Header**

- [ ] a task to delete
''');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'));
      var cubit = InboxTasksCubit(manager, false);
      await Future.delayed(Duration.zero);

      var task = manager.tasks[0];
      await cubit.deleteTaskPressed(task);

      expect(manager.tasks, isEmpty);
      var content = await storage.getFile('/test.md').readAsString();
      expect(content.contains('a task to delete'), isFalse);

      await cubit.close();
    });

    test(
        'isBlockedFromLeavingToday is true only when due today and includeDueTasksInToday is enabled',
        () async {
      var storage = InMemoryTasksFileStorage();
      var manager = TaskManager(storage);
      var cubit = InboxTasksCubit(manager, false);

      var dueToday = Task('due today', due: DateTime.now());
      var dueLater = Task('due later',
          due: DateTime.now().add(const Duration(days: 3)));

      manager.includeDueTasksInToday = true;
      expect(cubit.isBlockedFromLeavingToday(dueToday), isTrue);
      expect(cubit.isBlockedFromLeavingToday(dueLater), isFalse);

      manager.includeDueTasksInToday = false;
      expect(cubit.isBlockedFromLeavingToday(dueToday), isFalse);

      await cubit.close();
    });

    test(
        'removeFromTodayPressed clears the schedule when not blocked, and leaves it when blocked',
        () async {
      var storage = InMemoryTasksFileStorage();
      await storage.getFile('/test.md').writeAsString('''**Header**

- [ ] blocked task 📅 due-today-not-used
- [ ] free task
''');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/test.md'));
      var cubit = InboxTasksCubit(manager, false);
      await Future.delayed(Duration.zero);

      var blockedTask = manager.tasks[0];
      blockedTask.due = DateTime.now();
      blockedTask.scheduled = DateTime.now();
      manager.includeDueTasksInToday = true;

      var freeTask = manager.tasks[1];
      freeTask.scheduled = DateTime.now();

      cubit.removeFromTodayPressed(blockedTask);
      await Future.delayed(Duration.zero);
      expect(blockedTask.scheduled, isNotNull);

      cubit.removeFromTodayPressed(freeTask);
      await Future.delayed(Duration.zero);
      expect(freeTask.scheduled, isNull);

      await cubit.close();
    });

    test(
        'swipeHintShown reads/writes the today-vs-inbox flag independently',
        () async {
      var storage = InMemoryTasksFileStorage();
      var manager = TaskManager(storage);
      // today: false throughout, matching this file's established pattern
      // (see the comment above) — this exercises the Inbox branch of the
      // swipeHintShown/markSwipeHintShown delegation.
      var cubit = InboxTasksCubit(manager, false);

      expect(cubit.swipeHintShown, isFalse);

      await cubit.markSwipeHintShown();
      expect(cubit.swipeHintShown, isTrue);

      // The Today flag is a separate field on the same settings singleton
      // and must be unaffected by marking the Inbox hint as shown.
      expect(SettingsController.getInstance().swipeHintShownToday, isFalse);

      await cubit.close();
    });
  });
}
