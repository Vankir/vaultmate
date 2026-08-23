import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/onboarding/onboarding_flow.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

class FakeTaskManager extends Fake implements TaskManager {}

class FakeSettingsController extends Fake implements SettingsController {
  @override
  String taskFormatPreference = 'inline';

  @override
  String? vaultDirectory;

  @override
  Future<void> updateTaskFormatPreference(String value) async {
    taskFormatPreference = value;
  }

  @override
  Future<void> updateVaultDirectory(String? newVaultDirectory) async {
    vaultDirectory = newVaultDirectory;
  }

  @override
  Future<void> updateOnboardingComplete(bool value) async {}
}

const _folderScreenPrompt =
    "Pick the folder where your Obsidian vault is stored.\n\n"
    "VaultMate needs this to find and show your tasks.";

void main() {
  Widget wrap(FakeSettingsController settings) {
    // TaskFormatScreen/FolderSelectionScreen read the ambient
    // SettingsController.getInstance() singleton directly (matching how
    // the rest of the app does it, e.g. TaskEditorCubit), so it must be
    // the same instance passed into OnboardingFlow.
    SettingsController.setInstance(settings);
    return MaterialApp(
      home: OnboardingFlow(
        settingsController: settings,
        taskManager: FakeTaskManager(),
      ),
    );
  }

  testWidgets(
      'a brand-new user sees the welcome screen first, with no other screen before it (US1)',
      (tester) async {
    await tester.pumpWidget(wrap(FakeSettingsController()));

    expect(find.text('Never Forget a Task'), findsOneWidget);
    expect(find.text(_folderScreenPrompt), findsNothing);
    expect(find.text('How should VaultMate save your tasks?'), findsNothing);
  });

  testWidgets('proceeding through all 3 screens reaches folder selection',
      (tester) async {
    await tester.pumpWidget(wrap(FakeSettingsController()));

    await tester.tap(find.text('Next')); // welcome -> taskFormat
    await tester.pump();
    expect(find.text('How should VaultMate save your tasks?'), findsOneWidget);

    await tester.tap(find.text('Next')); // taskFormat -> folderSelection
    await tester.pump(); // rebuild
    await tester.pump(); // let startScanning's post-frame callback resolve

    expect(find.text(_folderScreenPrompt), findsOneWidget);
  });

  testWidgets(
      'back-navigation from screen 3 to screen 2 preserves the earlier task-format choice (FR-009)',
      (tester) async {
    final settings = FakeSettingsController();
    await tester.pumpWidget(wrap(settings));

    await tester.tap(find.text('Next')); // -> taskFormat
    await tester.pump();

    await tester.tap(find.text('TaskNotes'));
    await tester.pump();
    await tester.tap(find.text('Next')); // -> folderSelection, saves choice
    await tester.pump();
    await tester.pump();

    expect(settings.taskFormatPreference, 'taskNote');
    expect(find.text(_folderScreenPrompt), findsOneWidget);

    await tester.tap(find.text('Back')); // -> back to taskFormat
    await tester.pump();
    expect(find.text('How should VaultMate save your tasks?'), findsOneWidget);

    // Proceed again without touching the selection: it should still be
    // "taskNote", not reset to the "inline" fallback default.
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(settings.taskFormatPreference, 'taskNote');
  });
}
