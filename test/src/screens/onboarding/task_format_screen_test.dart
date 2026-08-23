import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/onboarding/cubit/onboarding_flow_cubit.dart';
import 'package:obsi/src/screens/onboarding/task_format_screen.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

class FakeTaskManager extends Fake implements TaskManager {}

class FakeSettingsController extends Fake implements SettingsController {
  @override
  String taskFormatPreference = 'inline';
  String? lastUpdatedPreference;

  @override
  Future<void> updateTaskFormatPreference(String value) async {
    taskFormatPreference = value;
    lastUpdatedPreference = value;
  }
}

void main() {
  late FakeSettingsController settings;
  late OnboardingFlowCubit cubit;

  setUp(() {
    settings = FakeSettingsController();
    SettingsController.setInstance(settings);
    cubit = OnboardingFlowCubit(settings, FakeTaskManager());
    cubit.next(); // land on taskFormat step
  });

  Widget wrap() {
    return MaterialApp(
      home:
          BlocProvider.value(value: cubit, child: const TaskFormatScreen()),
    );
  }

  testWidgets('explains both formats and offers Inline/TaskNotes/Both (FR-003/FR-004)',
      (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('Inline tasks'), findsOneWidget);
    expect(find.text('TaskNotes'), findsOneWidget);
    expect(find.text('Both'), findsOneWidget);
    expect(
      find.textContaining('compatible with the Tasks plugin'),
      findsOneWidget,
    );
    expect(
      find.textContaining('compatible with the TaskNotes plugin'),
      findsOneWidget,
    );
  });

  testWidgets(
      'proceeding without changing the selection still saves "inline" (FR-016)',
      (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(settings.lastUpdatedPreference, 'inline');
    expect(cubit.state.step, OnboardingStep.folderSelection);
  });

  testWidgets('selecting TaskNotes and proceeding saves it (FR-005)',
      (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('TaskNotes'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(settings.lastUpdatedPreference, 'taskNote');
    expect(cubit.state.step, OnboardingStep.folderSelection);
  });

  testWidgets('Back returns to the welcome step', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Back'));
    await tester.pump();

    expect(cubit.state.step, OnboardingStep.welcome);
  });
}
