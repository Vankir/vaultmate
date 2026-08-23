import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/settings/settings_service.dart';
import 'package:obsi/src/widgets/task_card.dart';

class MockSettingsController extends Mock implements SettingsController {
  @override
  String get dateTemplate => 'yyyy-MM-dd';

  @override
  SortMode get sortMode => SortMode.none;
}

void main() {
  setUp(() {
    SettingsController.setInstance(MockSettingsController());
  });

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Material(child: child)));

  const depthIndentKey = Key('task_card_depth_indent');
  Key markerKey(int level) => Key('task_card_depth_marker_$level');

  Task buildTask() => Task('Sample task');

  group('TaskCard depth rendering', () {
    testWidgets('depth 0 (default) renders with no indent and no markers',
        (tester) async {
      await tester.pumpWidget(wrap(TaskCard(buildTask())));

      expect(find.byKey(depthIndentKey), findsNothing);
      expect(find.byKey(markerKey(0)), findsNothing);
    });

    testWidgets('depth 1 renders one indent wrapper and one marker',
        (tester) async {
      await tester.pumpWidget(wrap(TaskCard(buildTask(), depth: 1)));

      expect(find.byKey(depthIndentKey), findsOneWidget);
      expect(find.byKey(markerKey(0)), findsOneWidget);
      expect(find.byKey(markerKey(1)), findsNothing);
    });

    testWidgets(
        'depth 2 renders two markers and a larger indent than depth 1',
        (tester) async {
      await tester.pumpWidget(wrap(TaskCard(buildTask(), depth: 1)));
      final depth1Padding =
          tester.widget<Padding>(find.byKey(depthIndentKey)).padding;

      await tester.pumpWidget(wrap(TaskCard(buildTask(), depth: 2)));
      final depth2Padding =
          tester.widget<Padding>(find.byKey(depthIndentKey)).padding;

      expect(find.byKey(markerKey(0)), findsOneWidget);
      expect(find.byKey(markerKey(1)), findsOneWidget);
      expect(find.byKey(markerKey(2)), findsNothing);
      expect((depth2Padding as EdgeInsets).left,
          greaterThan((depth1Padding as EdgeInsets).left));
    });

    testWidgets(
        'depth beyond the visual cap renders identically to the cap level',
        (tester) async {
      await tester.pumpWidget(wrap(TaskCard(buildTask(), depth: 5)));
      final cappedPadding =
          tester.widget<Padding>(find.byKey(depthIndentKey)).padding;
      expect(find.byKey(markerKey(4)), findsOneWidget);
      expect(find.byKey(markerKey(5)), findsNothing);

      await tester.pumpWidget(wrap(TaskCard(buildTask(), depth: 9)));
      final deepPadding =
          tester.widget<Padding>(find.byKey(depthIndentKey)).padding;

      // Still only 5 markers (0-4) even though depth is 9 - deeper nesting
      // renders at the same maximum indentation as depth 5, per FR-006.
      expect(find.byKey(markerKey(4)), findsOneWidget);
      expect(find.byKey(markerKey(5)), findsNothing);
      expect(deepPadding, cappedPadding);
    });

    testWidgets(
        'a depth > 0 card lays out without error inside a ListView '
        '(the real usage context in _createFileViews)', (tester) async {
      // Regression test: Material/Scaffold gives bounded height, which
      // hides layout bugs that only show up when the incoming height
      // constraint is unbounded - exactly what every ListView item gets.
      // This reproduces the real "RenderBox was not laid out: 'hasSize'"
      // crash a Row(crossAxisAlignment: stretch) with no IntrinsicHeight
      // wrapper produced here.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [TaskCard(buildTask(), depth: 2)],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(depthIndentKey), findsOneWidget);
    });
  });
}
