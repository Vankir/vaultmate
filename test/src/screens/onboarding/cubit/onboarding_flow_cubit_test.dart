import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/onboarding/cubit/onboarding_flow_cubit.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';

/// Hand-written fakes rather than Mockito `Mock`s: both `TaskManager` and
/// `SettingsController` have methods returning bare/void `Future`s that
/// Mockito's dummy-value generation for manual (non-codegen) mocks doesn't
/// handle reliably. Recording state on plain fields is simpler and just as
/// verifiable for this cubit's small surface.
class FakeTaskManager extends Fake implements TaskManager {
  String? loadedPath;

  @override
  Future loadTasks(String path,
      {String taskFilter = "", String taskNotePath = ""}) async {
    loadedPath = path;
  }
}

class FakeSettingsController extends Fake implements SettingsController {
  String? updatedVaultDirectory;
  int updateVaultDirectoryCallCount = 0;
  bool? updatedOnboardingComplete;
  int updateOnboardingCompleteCallCount = 0;

  @override
  Future<void> updateVaultDirectory(String? newVaultDirectory) async {
    updatedVaultDirectory = newVaultDirectory;
    updateVaultDirectoryCallCount++;
  }

  @override
  Future<void> updateOnboardingComplete(bool value) async {
    updatedOnboardingComplete = value;
    updateOnboardingCompleteCallCount++;
  }
}

void main() {
  late FakeSettingsController settings;
  late FakeTaskManager taskManager;
  late OnboardingFlowCubit cubit;

  setUp(() {
    settings = FakeSettingsController();
    taskManager = FakeTaskManager();
    cubit = OnboardingFlowCubit(settings, taskManager);
  });

  test('starts on welcome', () {
    expect(cubit.state.step, OnboardingStep.welcome);
  });

  test('next() advances welcome -> taskFormat -> folderSelection, then stops',
      () {
    cubit.next();
    expect(cubit.state.step, OnboardingStep.taskFormat);

    cubit.next();
    expect(cubit.state.step, OnboardingStep.folderSelection);

    cubit.next();
    expect(cubit.state.step, OnboardingStep.folderSelection);
  });

  test(
      'back() reverses taskFormat -> welcome and folderSelection -> taskFormat',
      () {
    cubit.next();
    cubit.next();
    expect(cubit.state.step, OnboardingStep.folderSelection);

    cubit.back();
    expect(cubit.state.step, OnboardingStep.taskFormat);

    cubit.back();
    expect(cubit.state.step, OnboardingStep.welcome);

    cubit.back();
    expect(cubit.state.step, OnboardingStep.welcome);
  });

  test('complete() is a no-op with an empty folder (FR-007)', () async {
    cubit.next();
    cubit.next();
    expect(cubit.state.step, OnboardingStep.folderSelection);

    await cubit.complete('');

    expect(cubit.state.step, OnboardingStep.folderSelection);
    expect(settings.updateVaultDirectoryCallCount, 0);
  });

  test('complete() is a no-op unless already on the folderSelection step',
      () async {
    await cubit.complete('/some/vault');

    expect(cubit.state.step, OnboardingStep.welcome);
    expect(settings.updateVaultDirectoryCallCount, 0);
  });

  test('complete() with a valid folder persists settings and finishes',
      () async {
    cubit.next();
    cubit.next();

    await cubit.complete('/some/vault');

    expect(cubit.state.step, OnboardingStep.complete);
    expect(settings.updatedVaultDirectory, '/some/vault');
    expect(settings.updateVaultDirectoryCallCount, 1);
    expect(settings.updatedOnboardingComplete, true);
    expect(settings.updateOnboardingCompleteCallCount, 1);
    expect(taskManager.loadedPath, '/some/vault');
  });
}
