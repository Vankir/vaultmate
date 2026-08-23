import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/core/tasks/task_source.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/task_editor/cubit/task_editor_cubit.dart';
import 'package:obsi/src/screens/task_editor/task_editor.dart';

class FakeTaskManager extends Fake implements TaskManager {
  @override
  List<String> get allTags => const [];
}

class FakeSettingsController extends Fake implements SettingsController {
  @override
  String taskFormatPreference = 'inline';

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
  String dateTemplate = 'yyyy-MM-dd HH:mm';
}

void main() {
  testWidgets(
      'no layout overflow when every date field (due/scheduled/start/created/done/cancelled) is set',
      (tester) async {
    SettingsController.setInstance(FakeSettingsController());
    final now = DateTime(2026, 8, 23, 14, 30);
    final task = Task(
      'A task with every date field populated',
      created: now,
      done: now,
      cancelled: now,
      due: now,
      scheduled: now,
      start: now,
      taskSource: TaskSource(0, 'notes.md', 0, 10),
    );

    await tester.pumpWidget(MaterialApp(
      home: BlocProvider(
        create: (_) => TaskEditorCubit(FakeTaskManager(), task: task),
        child: const TaskEditor(),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
