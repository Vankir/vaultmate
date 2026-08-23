import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

part 'onboarding_flow_state.dart';

/// Drives the single, mandatory 3-screen onboarding sequence (Welcome, Task
/// Format Choice, Folder Selection) that replaces today's two independent
/// gates (see lib/app.dart). There is no "skip" transition anywhere in this
/// state machine: `next()`/`back()` only move between welcome/taskFormat/
/// folderSelection, and `complete()` is the only way to reach the terminal
/// `complete` step, gated on a valid, non-empty vault folder.
class OnboardingFlowCubit extends Cubit<OnboardingFlowState> {
  final SettingsController _settings;
  final TaskManager _taskManager;

  OnboardingFlowCubit(this._settings, this._taskManager)
      : super(const OnboardingFlowState());

  void next() {
    switch (state.step) {
      case OnboardingStep.welcome:
        emit(state.copyWith(step: OnboardingStep.taskFormat));
        break;
      case OnboardingStep.taskFormat:
        emit(state.copyWith(step: OnboardingStep.folderSelection));
        break;
      case OnboardingStep.folderSelection:
      case OnboardingStep.complete:
        break;
    }
  }

  void back() {
    switch (state.step) {
      case OnboardingStep.taskFormat:
        emit(state.copyWith(step: OnboardingStep.welcome));
        break;
      case OnboardingStep.folderSelection:
        emit(state.copyWith(step: OnboardingStep.taskFormat));
        break;
      case OnboardingStep.welcome:
      case OnboardingStep.complete:
        break;
    }
  }

  /// Completes onboarding once a valid vault folder has been chosen.
  /// `complete` can never be reached with a blank folder or from any step
  /// other than `folderSelection` (FR-007/FR-010).
  Future<void> complete(String vaultDirectory) async {
    if (state.step != OnboardingStep.folderSelection) return;
    if (vaultDirectory.isEmpty) return;

    _taskManager.loadTasks(vaultDirectory);
    await _settings.updateVaultDirectory(vaultDirectory);
    await _settings.updateOnboardingComplete(true);

    emit(state.copyWith(step: OnboardingStep.complete));
  }
}
