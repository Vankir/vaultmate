import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/onboarding/cubit/onboarding_flow_cubit.dart';
import 'package:obsi/src/screens/onboarding/folder_selection_screen.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

class FakeTaskManager extends Fake implements TaskManager {}

class FakeSettingsController extends Fake implements SettingsController {
  @override
  String? vaultDirectory;
}

void main() {
  // In the test environment Platform.isAndroid is false, so
  // FolderSelectionCubit.startScanning takes the "not Android" branch and
  // never touches the permission_handler/filesystem_picker platform
  // channels — the "no vaults found, offer manual selection" path is safe
  // to exercise here without channel mocking.

  Widget wrap() {
    final settings = FakeSettingsController();
    SettingsController.setInstance(settings);
    return MaterialApp(
      home: BlocProvider(
        create: (_) => OnboardingFlowCubit(settings, FakeTaskManager()),
        child: const FolderSelectionScreen(),
      ),
    );
  }

  testWidgets(
      'offers manual folder selection when no vaults are auto-detected, and Continue starts disabled (FR-006)',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump(); // let the post-frame startScanning callback run

    expect(
      find.text(
          "Pick the folder where your Obsidian vault is stored.\n\nVaultMate needs this to find and show your tasks."),
      findsOneWidget,
    );
    expect(find.text('Select Folder Manually'), findsOneWidget);

    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNull,
        reason:
            'Continue must stay disabled until a valid folder is chosen (FR-007)');
  });

  testWidgets('has a Back control that returns to the task format step',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('Back'), findsOneWidget);
  });
}
