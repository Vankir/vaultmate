import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
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
  ViewMode get viewMode => ViewMode.grouped;
}

void main() {
  setUp(() {
    SettingsController.setInstance(MockSettingsController());
  });

  // today: false throughout, matching the established pattern in
  // inbox_tasks_cubit_swipe_test.dart, to avoid the today-only notification/
  // home-widget side effects in tasksChangedListener that need plugin
  // channels not available in a plain test.
  group('InboxTasksCubit collapse/expand (FR-012-FR-016)', () {
    test('isCollapsed is false for every task before any interaction',
        () async {
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/fileA.md')
          .writeAsString('- [ ] parent\n  - [ ] child\n');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/fileA.md'));
      var cubit = InboxTasksCubit(manager, false);
      await Future.delayed(Duration.zero);

      for (final task in manager.tasks) {
        expect(cubit.isCollapsed(task), isFalse);
      }

      await cubit.close();
    });

    test('toggleCollapsed marks a task collapsed, and again un-marks it',
        () async {
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/fileA.md')
          .writeAsString('- [ ] parent\n  - [ ] child\n');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/fileA.md'));
      var cubit = InboxTasksCubit(manager, false);
      await Future.delayed(Duration.zero);

      var parent =
          manager.tasks.firstWhere((t) => t.description == 'parent');

      cubit.toggleCollapsed(parent);
      expect(cubit.isCollapsed(parent), isTrue);

      cubit.toggleCollapsed(parent);
      expect(cubit.isCollapsed(parent), isFalse);

      await cubit.close();
    });

    test(
        'collapseAllInFile marks every task with children in that file, and '
        'leaves a different file untouched', () async {
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/fileA.md')
          .writeAsString('- [ ] parentA\n  - [ ] childA\n- [ ] leafA\n');
      await storage
          .getFile('/fileB.md')
          .writeAsString('- [ ] parentB\n  - [ ] childB\n');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/fileA.md'));
      var cubit = InboxTasksCubit(manager, false);
      await Future.delayed(Duration.zero);

      var parentA =
          manager.tasks.firstWhere((t) => t.description == 'parentA');
      var leafA = manager.tasks.firstWhere((t) => t.description == 'leafA');
      var parentB =
          manager.tasks.firstWhere((t) => t.description == 'parentB');

      cubit.collapseAllInFile('/fileA.md');

      expect(cubit.isCollapsed(parentA), isTrue);
      expect(cubit.isCollapsed(leafA), isFalse); // no children - never marked
      expect(cubit.isCollapsed(parentB), isFalse); // different file

      await cubit.close();
    });

    test('expandAllInFile clears only that file\'s collapsed ids', () async {
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/fileA.md')
          .writeAsString('- [ ] parentA\n  - [ ] childA\n');
      await storage
          .getFile('/fileB.md')
          .writeAsString('- [ ] parentB\n  - [ ] childB\n');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/fileA.md'));
      var cubit = InboxTasksCubit(manager, false);
      await Future.delayed(Duration.zero);

      var parentA =
          manager.tasks.firstWhere((t) => t.description == 'parentA');
      var parentB =
          manager.tasks.firstWhere((t) => t.description == 'parentB');

      cubit.collapseAllInFile('/fileA.md');
      cubit.collapseAllInFile('/fileB.md');
      expect(cubit.isCollapsed(parentA), isTrue);
      expect(cubit.isCollapsed(parentB), isTrue);

      cubit.expandAllInFile('/fileA.md');

      expect(cubit.isCollapsed(parentA), isFalse);
      expect(cubit.isCollapsed(parentB), isTrue);

      await cubit.close();
    });

    test('clearCollapsedTasks empties the set regardless of what was collapsed',
        () async {
      var storage = InMemoryTasksFileStorage();
      await storage
          .getFile('/fileA.md')
          .writeAsString('- [ ] parentA\n  - [ ] childA\n');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/fileA.md'));
      var cubit = InboxTasksCubit(manager, false);
      await Future.delayed(Duration.zero);

      var parentA =
          manager.tasks.firstWhere((t) => t.description == 'parentA');
      cubit.toggleCollapsed(parentA);
      expect(cubit.isCollapsed(parentA), isTrue);

      cubit.clearCollapsedTasks();

      expect(cubit.isCollapsed(parentA), isFalse);

      await cubit.close();
    });

    test(
        'hasCollapsibleTasks/allCollapsedInFile/toggleCollapseAllInFile '
        'behave as a single two-state toggle', () async {
      var storage = InMemoryTasksFileStorage();
      await storage.getFile('/fileA.md').writeAsString(
          '- [ ] parentA1\n  - [ ] childA1\n- [ ] parentA2\n  - [ ] childA2\n- [ ] leafA\n');
      var manager = TaskManager(storage);
      await manager.loadTasks(p.dirname('/fileA.md'));
      var cubit = InboxTasksCubit(manager, false);
      await Future.delayed(Duration.zero);

      expect(cubit.hasCollapsibleTasks('/fileA.md'), isTrue);
      expect(cubit.hasCollapsibleTasks('/nonexistent.md'), isFalse);

      // Nothing collapsed yet.
      expect(cubit.allCollapsedInFile('/fileA.md'), isFalse);

      // First toggle: nothing is fully collapsed, so it collapses everything.
      cubit.toggleCollapseAllInFile('/fileA.md');
      expect(cubit.allCollapsedInFile('/fileA.md'), isTrue);

      // Second toggle: everything is collapsed, so it expands everything.
      cubit.toggleCollapseAllInFile('/fileA.md');
      expect(cubit.allCollapsedInFile('/fileA.md'), isFalse);
      var parentA1 =
          manager.tasks.firstWhere((t) => t.description == 'parentA1');
      var parentA2 =
          manager.tasks.firstWhere((t) => t.description == 'parentA2');
      expect(cubit.isCollapsed(parentA1), isFalse);
      expect(cubit.isCollapsed(parentA2), isFalse);

      // Only one of two collapsible tasks collapsed - not "all collapsed"
      // yet, so the next toggle collapses the rest rather than expanding.
      cubit.toggleCollapsed(parentA1);
      expect(cubit.allCollapsedInFile('/fileA.md'), isFalse);
      cubit.toggleCollapseAllInFile('/fileA.md');
      expect(cubit.isCollapsed(parentA1), isTrue);
      expect(cubit.isCollapsed(parentA2), isTrue);

      await cubit.close();
    });
  });
}
