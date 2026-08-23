import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/onboarding/cubit/onboarding_flow_cubit.dart';
import 'package:obsi/src/screens/onboarding/welcome_screen.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

class FakeTaskManager extends Fake implements TaskManager {}

class FakeSettingsController extends Fake implements SettingsController {}

void main() {
  Widget wrap(OnboardingFlowCubit cubit) {
    return MaterialApp(
      home: BlocProvider.value(value: cubit, child: const WelcomeScreen()),
    );
  }

  testWidgets(
      'shows all key feature highlights with no swipe/page control (FR-002, SC-003)',
      (tester) async {
    final cubit =
        OnboardingFlowCubit(FakeSettingsController(), FakeTaskManager());
    await tester.pumpWidget(wrap(cubit));

    expect(find.text('Never Forget a Task'), findsOneWidget);
    expect(find.text('Your Tasks, Everywhere'), findsOneWidget);
    expect(find.text('Filter Your Tasks'), findsOneWidget);

    // No PageView anywhere: structurally, there is no swipe-based
    // navigation for the user to page through (SC-003).
    expect(find.byType(PageView), findsNothing);

    // No Skip affordance anywhere on the screen (FR-008).
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('tapping Next advances the flow to the task format step',
      (tester) async {
    final cubit =
        OnboardingFlowCubit(FakeSettingsController(), FakeTaskManager());
    await tester.pumpWidget(wrap(cubit));

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(cubit.state.step, OnboardingStep.taskFormat);
  });
}
