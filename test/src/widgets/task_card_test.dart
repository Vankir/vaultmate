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

  group('TaskCard collapse/expand control', () {
    const collapseToggleKey = Key('task_card_collapse_toggle');

    testWidgets('hasChildren false renders no control regardless of isCollapsed',
        (tester) async {
      await tester.pumpWidget(wrap(TaskCard(buildTask())));
      expect(find.byKey(collapseToggleKey), findsNothing);

      await tester.pumpWidget(
          wrap(TaskCard(buildTask(), hasChildren: false, isCollapsed: true)));
      expect(find.byKey(collapseToggleKey), findsNothing);
    });

    testWidgets(
        'hasChildren true with a callback renders a control that invokes it '
        'on tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(TaskCard(
        buildTask(),
        hasChildren: true,
        isCollapsed: false,
        onToggleCollapse: () => tapped = true,
      )));

      expect(find.byKey(collapseToggleKey), findsOneWidget);
      await tester.tap(find.byKey(collapseToggleKey));
      expect(tapped, isTrue);
    });

    testWidgets('isCollapsed renders a visibly different icon than expanded',
        (tester) async {
      await tester.pumpWidget(wrap(TaskCard(
        buildTask(),
        hasChildren: true,
        isCollapsed: false,
        onToggleCollapse: () {},
      )));
      final expandedIcon =
          tester.widget<IconButton>(find.byKey(collapseToggleKey)).icon;

      await tester.pumpWidget(wrap(TaskCard(
        buildTask(),
        hasChildren: true,
        isCollapsed: true,
        onToggleCollapse: () {},
      )));
      final collapsedIcon =
          tester.widget<IconButton>(find.byKey(collapseToggleKey)).icon;

      expect(
          (expandedIcon as Icon).icon != (collapsedIcon as Icon).icon, isTrue);
    });

    testWidgets(
        'the checkbox renders the same size whether or not the task has '
        'children (a stacked toggle must not shrink it)', (tester) async {
      await tester.pumpWidget(wrap(TaskCard(buildTask())));
      final plainCheckboxSize = tester.getSize(find.byType(Checkbox));

      await tester.pumpWidget(wrap(TaskCard(
        buildTask(),
        hasChildren: true,
        isCollapsed: false,
        onToggleCollapse: () {},
      )));
      final parentCheckboxSize = tester.getSize(find.byType(Checkbox));

      expect(parentCheckboxSize, plainCheckboxSize);
    });
  });

  group('TaskCard subtitle stays on one line', () {
    testWidgets(
        'scheduled and due dates never force a line break between them',
        (tester) async {
      final task = Task(
        'Task with dates',
        scheduled: DateTime(2026, 1, 5),
        due: DateTime(2026, 1, 10),
      );

      await tester.pumpWidget(wrap(TaskCard(task)));

      final subtitleText = tester.widget<Text>(find.byWidgetPredicate(
          (w) => w is Text && w.data != null && w.data!.contains('2026')));

      expect(subtitleText.data!.contains('\n'), isFalse);
      expect(subtitleText.maxLines, 1);
      expect(subtitleText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('still one line (via RichText) when the task also has tags',
        (tester) async {
      final task = Task(
        'Task with dates #work',
        scheduled: DateTime(2026, 1, 5),
        due: DateTime(2026, 1, 10),
      );

      await tester.pumpWidget(wrap(TaskCard(task)));

      final subtitleRichText = tester.widget<RichText>(find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('2026')));

      expect(subtitleRichText.text.toPlainText().contains('\n'), isFalse);
      expect(subtitleRichText.maxLines, 1);
      expect(subtitleRichText.overflow, TextOverflow.ellipsis);
      expect(find.text('#work'), findsOneWidget);
    });
  });
}
