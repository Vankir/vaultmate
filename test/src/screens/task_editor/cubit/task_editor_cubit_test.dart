import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/core/tasks/task_source.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/task_editor/cubit/task_editor_cubit.dart';

class FakeTaskManager extends Fake implements TaskManager {
  String? lastSavedFilePath;

  @override
  Future saveTask(Task task,
      {String? filePath,
      String? saveMarker,
      bool dataViewDefaultMarkdownFormat = false}) async {
    lastSavedFilePath = filePath;
  }
}

class FakeSettingsController extends Fake implements SettingsController {
  @override
  final String taskFormatPreference;

  @override
  String tasksFile = 'obsi_tasks.md';

  @override
  String? vaultDirectory = '/vault';

  @override
  String? filePathPattern;

  @override
  String? saveMarker;

  @override
  bool dataViewDefaultMarkdownFormat = false;

  @override
  String? lastTaskNoteFolder;

  @override
  Future<void> updateLastTaskNoteFolder(String? folder) async {
    lastTaskNoteFolder = folder;
  }

  FakeSettingsController(this.taskFormatPreference);
}

void main() {
  final taskManager = FakeTaskManager();

  void withPreference(String preference) {
    SettingsController.setInstance(FakeSettingsController(preference));
  }

  group('new task format pre-selection (FR-014/FR-016)', () {
    test('"inline" preference does not pre-select TaskNote format', () {
      withPreference('inline');
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      expect(cubit.isNewTask, isTrue);
      expect(cubit.taskNoteFormat, isFalse);
    });

    test('"taskNote" preference pre-selects TaskNote format', () {
      withPreference('taskNote');
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      expect(cubit.isNewTask, isTrue);
      expect(cubit.taskNoteFormat, isTrue);
    });

    test('"both" preference pre-selects nothing, matching today\'s default',
        () {
      withPreference('both');
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      expect(cubit.isNewTask, isTrue);
      expect(cubit.taskNoteFormat, isFalse);
    });
  });

  group('TaskNote format choice visibility', () {
    test('hidden when the preference is "inline" (a firm default is set)',
        () {
      withPreference('inline');
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      expect(cubit.showTaskFormatChoice, isFalse);
    });

    test('hidden when the preference is "taskNote" (a firm default is set)',
        () {
      withPreference('taskNote');
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      expect(cubit.showTaskFormatChoice, isFalse);
    });

    test('shown when the preference is "both" (no firm default to rely on)',
        () {
      withPreference('both');
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      expect(cubit.showTaskFormatChoice, isTrue);
    });

    test('hidden when editing an existing task, regardless of preference',
        () {
      withPreference('both');
      final existingTask = Task(
        'Existing task',
        taskSource: TaskSource(0, 'notes.md', 0, 10),
      );
      final cubit = TaskEditorCubit(taskManager, task: existingTask);

      expect(cubit.showTaskFormatChoice, isFalse);
    });
  });

  test('the pre-selected default can still be overridden per task (FR-015)',
      () {
    withPreference('taskNote');
    final cubit = TaskEditorCubit(taskManager, task: Task(''));
    expect(cubit.taskNoteFormat, isTrue);

    cubit.toggleTaskNoteFormat(false);

    expect(cubit.taskNoteFormat, isFalse);
  });

  test(
      'editing an existing task is never pre-selected by the preference (FR-018)',
      () {
    withPreference('taskNote');
    final existingTask = Task(
      'Existing task',
      taskSource: TaskSource(0, 'notes.md', 0, 10),
    );
    final cubit = TaskEditorCubit(taskManager, task: existingTask);

    expect(cubit.isNewTask, isFalse);
    expect(cubit.taskNoteFormat, isFalse);
  });

  group('TaskNote file name sanitization', () {
    test('collapses a multi-line description into a single-line file name',
        () {
      final filename = TaskEditorCubit.sanitizeTaskNoteFilename(
          'Buy milk\nand eggs\nfrom the store');

      expect(filename.contains('\n'), isFalse);
      expect(filename, 'Buy milk and eg');
    });

    test('collapses other whitespace runs (tabs, repeated spaces) too', () {
      final filename =
          TaskEditorCubit.sanitizeTaskNoteFilename('Buy   milk\tnow');

      expect(filename, 'Buy milk now');
    });

    test('strips invalid filename characters', () {
      final filename =
          TaskEditorCubit.sanitizeTaskNoteFilename('Fix "bug" <urgent>');

      expect(filename.contains(RegExp(r'[/\\:*?"<>|]')), isFalse);
    });

    test('never leaves a trailing space when truncated mid-run', () {
      // 15th character lands right where the whitespace run would be.
      final filename =
          TaskEditorCubit.sanitizeTaskNoteFilename('123456789012345 next');

      expect(filename.endsWith(' '), isFalse);
    });
  });

  group('target file display and selection', () {
    test('defaults to the basename of the default tasks path', () {
      withPreference('inline');
      final cubit = TaskEditorCubit(taskManager,
          task: Task(''), createTasksPath: '/vault/obsi_tasks.md');

      expect(cubit.targetFileDisplayName, 'obsi_tasks.md');
    });

    test('falls back to the configured default tasks file when no path is given',
        () {
      final settings = FakeSettingsController('inline')
        ..tasksFile = 'my_tasks.md';
      SettingsController.setInstance(settings);
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      expect(cubit.targetFileDisplayName, 'my_tasks.md');
    });

    testWidgets(
        'chooseTargetFile updates the target file and saveTask uses it',
        (tester) async {
      final settings = FakeSettingsController('inline')
        ..filePathPattern = '{vault}/Daily/notes.md';
      SettingsController.setInstance(settings);
      final freshTaskManager = FakeTaskManager();
      final cubit = TaskEditorCubit(freshTaskManager,
          task: Task(''), createTasksPath: '/vault/obsi_tasks.md');
      cubit.setDescription('Buy milk');

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => cubit.chooseTargetFile(context),
            child: const Text('choose'),
          );
        }),
      ));

      expect(cubit.targetFileDisplayName, 'obsi_tasks.md');

      await tester.tap(find.text('choose'));
      await tester.pump();

      expect(cubit.targetFileDisplayName, 'notes.md');

      final buildContext = tester.element(find.byType(ElevatedButton));
      await cubit.saveTask(buildContext);

      expect(freshTaskManager.lastSavedFilePath, '/vault/Daily/notes.md');
    });
  });

  group('TaskNote folder display and reuse', () {
    test('shows "Choose folder" when no folder has ever been used', () {
      SettingsController.setInstance(FakeSettingsController('taskNote'));
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      expect(cubit.targetTaskNoteFolder, isNull);
      expect(cubit.targetTaskNoteFolderDisplayName, 'Choose folder');
    });

    test('shows the basename of the persisted last-used folder', () {
      SettingsController.setInstance(FakeSettingsController('taskNote')
        ..lastTaskNoteFolder = '/vault/Projects/Work');
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      expect(cubit.targetTaskNoteFolderDisplayName, 'Work');
    });

    test('the generated file name is empty until a description is typed',
        () {
      SettingsController.setInstance(FakeSettingsController('taskNote')
        ..lastTaskNoteFolder = '/vault/Notes');
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      expect(cubit.targetTaskNoteFileName, isEmpty);
      expect(cubit.targetTaskNoteDisplayPath, 'Notes');
    });

    test('the file name updates live as the description is typed', () {
      SettingsController.setInstance(FakeSettingsController('taskNote')
        ..lastTaskNoteFolder = '/vault/Notes');
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      cubit.setDescription('Buy milk');

      expect(cubit.targetTaskNoteFileName, 'Buy milk.md');
      expect(cubit.targetTaskNoteDisplayPath, 'Notes/Buy milk.md');
    });

    test('shows just the file name when no folder has been chosen yet', () {
      SettingsController.setInstance(FakeSettingsController('taskNote'));
      final cubit = TaskEditorCubit(taskManager, task: Task(''));

      cubit.setDescription('Buy milk');

      expect(cubit.targetTaskNoteFolder, isNull);
      expect(cubit.targetTaskNoteDisplayPath, 'Buy milk.md');
    });

    testWidgets(
        'saveTask uses the last-used folder directly, with no folder picker prompt needed',
        (tester) async {
      final settings = FakeSettingsController('taskNote')
        ..lastTaskNoteFolder = '/vault/Notes';
      SettingsController.setInstance(settings);
      final freshTaskManager = FakeTaskManager();
      final cubit = TaskEditorCubit(freshTaskManager, task: Task(''));
      cubit.setDescription('Buy milk');

      expect(cubit.taskNoteFormat, isTrue);

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => cubit.saveTask(context),
            child: const Text('save'),
          );
        }),
      ));

      // No folder picker prompt should appear: saveTask must resolve the
      // folder from the persisted setting alone and save straight away.
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(freshTaskManager.lastSavedFilePath, '/vault/Notes/Buy milk.md');
      // The chosen folder remains the persisted one (unchanged).
      expect(settings.lastTaskNoteFolder, '/vault/Notes');
    });
  });
}
