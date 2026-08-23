part of 'onboarding_flow_cubit.dart';

/// The 3 mandatory screens of the unified onboarding sequence, plus the
/// terminal `complete` state once a valid vault folder has been confirmed.
enum OnboardingStep { welcome, taskFormat, folderSelection, complete }

@immutable
class OnboardingFlowState {
  final OnboardingStep step;

  const OnboardingFlowState({this.step = OnboardingStep.welcome});

  OnboardingFlowState copyWith({OnboardingStep? step}) {
    return OnboardingFlowState(step: step ?? this.step);
  }
}
