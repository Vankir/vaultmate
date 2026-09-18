import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/system_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The native widget code re-creates the next occurrence of a recurring task on
/// its own (TaskWrapper.buildNextOccurrenceLine). It can only do that correctly
/// if the Dart side tells it the global task filter, because the filter is not a
/// tag on the task — the parser strips it out, so it is missing from the widget
/// data and the re-created task ends up invisible everywhere (#63).
///
/// These tests pin that hand-off: `updateWidget` must publish the filter to the
/// widget state under `HomeWidgetHandler.globalTaskFilterKey`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  late List<MethodCall> calls;

  Future<dynamic> fakeHomeWidget(MethodCall call) async {
    calls.add(call);
    return true;
  }

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, fakeHomeWidget);
    SharedPreferences.setMockInitialValues({'global_task_filter': '#task'});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SharedPreferences.setMockInitialValues({});
  });

  MethodCall savedFilterCall() {
    return calls.firstWhere(
      (call) =>
          call.method == 'saveWidgetData' &&
          call.arguments['id'] == HomeWidgetHandler.globalTaskFilterKey,
      orElse: () => throw StateError(
          'global task filter was not sent to the widget: $calls'),
    );
  }

  test('updateWidget publishes the global task filter to the widget', () async {
    await HomeWidgetHandler.updateWidget([]);

    expect(savedFilterCall().arguments['data'], '#task');
  });

  test('the filter is published before the widget is refreshed', () async {
    await HomeWidgetHandler.updateWidget([]);

    final filterIndex = calls.indexWhere((call) =>
        call.method == 'saveWidgetData' &&
        call.arguments['id'] == HomeWidgetHandler.globalTaskFilterKey);
    final updateIndex = calls.indexWhere((call) => call.method == 'updateWidget');

    expect(filterIndex, isNonNegative);
    expect(updateIndex, isNonNegative);
    expect(filterIndex, lessThan(updateIndex),
        reason: 'the widget would render before the filter is available');
  });

  test('an empty filter is published as an empty string, not skipped', () async {
    SharedPreferences.setMockInitialValues({});

    await HomeWidgetHandler.updateWidget([]);

    expect(savedFilterCall().arguments['data'], '');
  });
}
