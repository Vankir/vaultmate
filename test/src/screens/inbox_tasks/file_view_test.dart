import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/screens/inbox_tasks/file_view.dart';

void main() {
  group('FileView header layout', () {
    testWidgets(
        'a long file name with the collapse-all toggle does not overflow '
        'the header row', (tester) async {
      // Regression test: on a narrow screen, a long file name plus the
      // header's icon button(s) overflowed the header Row, because the
      // file-name GestureDetector had no flex/shrink behavior and always
      // claimed its full natural width.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: FileView(
              const [],
              fileName:
                  '/storage/emulated/0/Obsidian/a very long note file name that does not fit.md',
              vaultName: 'MyVault',
              allCollapsed: false,
              onToggleCollapseAll: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
          find.byKey(const Key('file_view_collapse_toggle')), findsOneWidget);
    });

    testWidgets('no toggle control when allCollapsed/onToggleCollapseAll are null',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FileView(
            const [],
            fileName: '/a.md',
            vaultName: 'MyVault',
          ),
        ),
      ));

      expect(find.byKey(const Key('file_view_collapse_toggle')), findsNothing);
    });

    testWidgets(
        'allCollapsed false shows a collapse-all icon that invokes the '
        'callback on tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FileView(
            const [],
            fileName: '/a.md',
            vaultName: 'MyVault',
            allCollapsed: false,
            onToggleCollapseAll: () => tapped = true,
          ),
        ),
      ));

      final collapseIcon = tester
          .widget<IconButton>(find.byKey(const Key('file_view_collapse_toggle')))
          .icon as Icon;
      expect(collapseIcon.icon, Icons.unfold_less);

      await tester.tap(find.byKey(const Key('file_view_collapse_toggle')));
      expect(tapped, isTrue);
    });

    testWidgets('allCollapsed true shows a visibly different (expand-all) icon',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FileView(
            const [],
            fileName: '/a.md',
            vaultName: 'MyVault',
            allCollapsed: true,
            onToggleCollapseAll: () {},
          ),
        ),
      ));

      final expandIcon = tester
          .widget<IconButton>(find.byKey(const Key('file_view_collapse_toggle')))
          .icon as Icon;
      expect(expandIcon.icon, Icons.unfold_more);
    });
  });
}
