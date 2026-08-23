import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/onboarding/cubit/onboarding_flow_cubit.dart';
import 'package:obsi/src/screens/onboarding/folder_selection_screen.dart';
import 'package:obsi/src/screens/onboarding/task_format_screen.dart';
import 'package:obsi/src/screens/onboarding/welcome_screen.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

/// Hosts the mandatory 3-screen onboarding sequence (Welcome, Task Format
/// Choice, Folder Selection) as a single `OnboardingFlowCubit`-driven flow.
/// Deliberately renders one screen at a time via a state switch rather than
/// a swipeable `PageView`, so there is no gesture that could let a user
/// bypass a step — the only ways to move between screens are the Next/Back
/// buttons each screen provides (FR-006/FR-008).
class OnboardingFlow extends StatelessWidget {
  final SettingsController settingsController;
  final TaskManager taskManager;

  const OnboardingFlow({
    super.key,
    required this.settingsController,
    required this.taskManager,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingFlowCubit(settingsController, taskManager),
      child: BlocBuilder<OnboardingFlowCubit, OnboardingFlowState>(
        builder: (context, state) {
          switch (state.step) {
            case OnboardingStep.welcome:
              return const WelcomeScreen();
            case OnboardingStep.taskFormat:
              return const TaskFormatScreen();
            case OnboardingStep.folderSelection:
              return const FolderSelectionScreen();
            case OnboardingStep.complete:
              // Transient: app.dart swaps this whole widget out for
              // MainNavigator as soon as settingsController notifies.
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
          }
        },
      ),
    );
  }
}
