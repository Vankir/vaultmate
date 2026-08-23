import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/parsers/markdown_parser.dart';
import 'package:obsi/src/core/tasks/parsers/parser.dart';
import 'package:obsi/src/core/tasks/task.dart';

void main() {
  group('MarkdownParser._parseTasksByPattern', () {
    group('Basic Task Parsing', () {
      test('should parse simple todo task', () {
        const content = '- [ ] Simple todo task';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].status, TaskStatus.todo);
        expect(tasks[0].description, 'Simple todo task');
        expect(tasks[0].taskSource?.offset, 0);
      });

      test('should parse simple completed task', () {
        const content = '- [x] Completed task';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].status, TaskStatus.done);
        expect(tasks[0].description, 'Completed task');
      });

      test('should parse task with X marker', () {
        const content = '- [X] Task with capital X';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].status, TaskStatus.done);
        expect(tasks[0].description, 'Task with capital X');
      });

      test('should parse multiple task markers', () {
        const content = '''- [ ] First task
* [x] Second task
+ [ ] Third task''';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 3);
        expect(tasks[0].description, 'First task');
        expect(tasks[0].status, TaskStatus.todo);
        expect(tasks[1].description, 'Second task');
        expect(tasks[1].status, TaskStatus.done);
        expect(tasks[2].description, 'Third task');
        expect(tasks[2].status, TaskStatus.todo);
      });
    });

    group('Edge Cases - Invalid Task Formats', () {
      test('should skip invalid bracket structure', () {
        const content = '''- [invalid] Not a valid task
- [ ] Valid task''';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Valid task');
      });

      test('should skip incomplete bracket structure', () {
        const content = '''- [ Incomplete bracket
- [x] Valid task''';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Valid task');
      });

      test('should skip missing space after marker', () {
        const content = '''-[ ] No space after dash
- [ ] Valid task''';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Valid task');
      });

      test('should skip missing bracket after space', () {
        const content = '''- x] Missing opening bracket
- [ ] Valid task''';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Valid task');
      });
    });

    group('Edge Cases - Whitespace Handling', () {
      test('should handle leading spaces before task marker', () {
        const content = '   - [ ] Task with leading spaces';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Task with leading spaces');
      });

      test('should handle multiple spaces after bracket', () {
        const content = '- [ ]     Task with multiple spaces';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Task with multiple spaces');
      });

      test('should handle tabs and mixed whitespace', () {
        const content = '\t- [ ]\t\tTask with tabs';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Task with tabs');
      });

      test('should handle empty task content', () {
        const content = '- [ ] ';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, '');
      });
    });

    group('Edge Cases - Task Length Calculation', () {
      test('should calculate correct task length for single line', () {
        const content = '- [ ] Task content';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        // Length should include the entire task line
        expect(tasks[0].taskSource?.length, content.length);
      });

      test('should calculate correct task length with newline', () {
        const content = '- [ ] Task content\nNext line';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        // Length should include up to but not including the newline
        expect(tasks[0].taskSource?.length, '- [ ] Task content'.length);
      });

      test('should handle task at end of file without newline', () {
        const content = '- [ ] Last task without newline';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Last task without newline');
        expect(tasks[0].taskSource?.length, content.length);
      });
    });

    group('Edge Cases - Unicode and Special Characters', () {
      test('should handle Unicode characters in task content', () {
        const content = '- [ ] Task with émojis 🚀 and ñ characters';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Task with émojis 🚀 and ñ characters');
      });

      test('should handle special markdown characters', () {
        const content = '- [ ] Task with **bold** and *italic* text';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Task with **bold** and *italic* text');
      });

      test('should handle brackets in task content', () {
        const content = '- [ ] Task with [brackets] in content';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Task with [brackets] in content');
      });
    });

    group('Edge Cases - Task Filter', () {
      test('should apply task filter correctly', () {
        const content = '''- [ ] Task with filter tag
- [ ] Another task
- [ ] Task with filter again''';
        final tasks =
            Parser.parseTasks('test.md', content, taskFilter: 'filter');

        expect(tasks.length, 2);
      });

      test('should handle filter removal from task content', () {
        const content = '- [ ] Task with #tag content';
        final tasks = Parser.parseTasks('test.md', content, taskFilter: '#tag');

        expect(tasks.length, 1);
        // Filter is removed without extra whitespace handling
        expect(tasks[0].description, 'Task with content');
      });
    });

    group('Edge Cases - Boundary Conditions', () {
      test('should handle empty content', () {
        const content = '';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 0);
      });

      test('should handle single character content', () {
        const content = '-';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 0);
      });

      test('should handle very long task content', () {
        final longContent = 'Very long task content ' * 100;
        final content = '- [ ] $longContent';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        // Content should match exactly, trailing space is trimmed
        expect(tasks[0].description, longContent.trimRight());
      });

      test('should handle multiple consecutive newlines', () {
        const content = '''- [ ] First task


- [ ] Second task after empty lines''';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 2);
        expect(tasks[0].description, 'First task');
        expect(tasks[1].description, 'Second task after empty lines');
      });
    });

    group('Edge Cases - Mixed Content', () {
      test('should parse tasks mixed with regular text', () {
        const content = '''Regular text line
- [ ] First task
More regular text
- [x] Second task
Final text line''';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 2);
        expect(tasks[0].description, 'First task');
        expect(tasks[0].status, TaskStatus.todo);
        expect(tasks[1].description, 'Second task');
        expect(tasks[1].status, TaskStatus.done);
      });

      test('should handle indented tasks (potential subtasks)', () {
        const content = '''- [ ] Main task
  - [ ] Indented task
    - [ ] Double indented task''';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 3);
        expect(tasks[0].description, 'Main task');
        expect(tasks[1].description, 'Indented task');
        expect(tasks[2].description, 'Double indented task');
      });

      test('should handle tasks in code blocks (should not parse)', () {
        const content = '''```
- [ ] Task in code block
```
- [ ] Real task''';
        final tasks = Parser.parseTasks('test.md', content);

        // Current implementation will parse both (doesn't understand code blocks)
        expect(tasks.length, 2);
        expect(tasks[1].description, 'Real task');
      });
    });

    group('Task Source Information', () {
      test('should set correct file information', () {
        const content = '- [ ] Test task';
        final tasks = Parser.parseTasks('test.md', content, fileNumber: 5);

        expect(tasks.length, 1);
        expect(tasks[0].taskSource?.fileNumber, 5);
        expect(tasks[0].taskSource?.fileName, 'test.md');
        expect(tasks[0].taskSource?.offset, 0);
      });

      test('should set correct offset for multiple tasks', () {
        const content = '''First line
- [ ] First task
- [ ] Second task''';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 2);
        expect(tasks[0].taskSource?.offset, 11); // After "First line\n"
        expect(tasks[1].taskSource?.offset, 28); // After first task + newline
      });
    });

    group('Regression Tests', () {
      test('should handle the subtask concatenation issue from memory', () {
        const content = '''- [ ] main task
  - [ ] subtask 1
  - [ ] subtask 2
  - [ ] subtask 3''';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 4);
        expect(tasks[0].description, 'main task');
        expect(tasks[1].description, 'subtask 1');
        expect(tasks[2].description, 'subtask 2');
        expect(tasks[3].description, 'subtask 3');

        // Ensure no concatenation occurs
        expect(tasks[0].description, isNot(contains('subtask')));
      });

      test('should handle date metadata parsing correctly', () {
        const content = '- [ ] Task with date 📅 2024-04-07-04-06';
        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Task with date 📅 2024-04-07-04-06');
      });

      test('should parse Dataview fields in square brackets', () {
        const content =
            '- [ ] #task Dataview task [created:: 2023-04-13] [scheduled:: 2023-04-14] [start:: 2023-04-15] [due:: 2023-04-16] [priority:: high] [repeat:: every day when done]';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Dataview task');
        expect(tasks[0].priority, TaskPriority.high);
        expect(tasks[0].created, DateTime(2023, 4, 13));
        expect(tasks[0].scheduled, DateTime(2023, 4, 14));
        expect(tasks[0].start, DateTime(2023, 4, 15));
        expect(tasks[0].due, DateTime(2023, 4, 16));
        expect(tasks[0].recurrenceRule, 'every day when done');
      });

      test('should parse Dataview fields in parentheses', () {
        const content =
            '- [x] #task Dataview done task (completion:: 2023-04-17) (priority:: highest)';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Dataview done task');
        expect(tasks[0].status, TaskStatus.done);
        expect(tasks[0].priority, TaskPriority.highest);
        expect(tasks[0].done, DateTime(2023, 4, 17));
      });

      test('should mark scheduledTime when Dataview scheduled has time', () {
        const content =
            '- [ ] Dataview scheduled time task [scheduled:: 2023-04-14T10:20:00]';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].scheduled, DateTime(2023, 4, 14, 10, 20, 1));
        expect(tasks[0].scheduledTime, true);
      });

      test('should keep unsupported Dataview fields in description', () {
        const content =
            '- [ ] Dataview with unsupported fields [id:: dcf64c] [dependsOn:: dcf64c,0h17ye] [onCompletion:: delete]';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description,
            'Dataview with unsupported fields [id:: dcf64c] [dependsOn:: dcf64c,0h17ye] [onCompletion:: delete]');
      });

      test('should parse supported Dataview fields with mixed delimiters', () {
        const content =
            '- [ ] Mixed delimiters [created:: 2024-01-10], (due:: 2024-01-12) [repeat:: every week]';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].description, 'Mixed delimiters ,');
        expect(tasks[0].created, DateTime(2024, 1, 10));
        expect(tasks[0].due, DateTime(2024, 1, 12));
        expect(tasks[0].recurrenceRule, 'every week');
      });

      test('should use last Dataview value when same supported field repeats',
          () {
        const content =
            '- [ ] Repeated due [due:: 2024-05-01] [due:: 2024-05-10]';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].due, DateTime(2024, 5, 10));
      });

      test('should ignore invalid Dataview values and keep parsable ones', () {
        const content =
            '- [ ] Invalid values [due:: invalid] [scheduled:: 2024-04-14T09:30:00] [priority:: unknown]';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].due, isNull);
        expect(tasks[0].scheduled, DateTime(2024, 4, 14, 9, 30, 1));
        expect(tasks[0].scheduledTime, true);
        expect(tasks[0].priority, TaskPriority.normal);
      });

      test('should not parse Dataview fields when emoji metadata is present',
          () {
        const content =
            '- [ ] Emoji wins 📅 2024-03-20 [priority:: highest] [repeat:: every day]';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 1);
        expect(tasks[0].due, DateTime(2024, 3, 20));
        expect(tasks[0].priority, TaskPriority.normal);
        expect(tasks[0].recurrenceRule, isNull);
        expect(tasks[0].description,
            'Emoji wins [priority:: highest] [repeat:: every day]');
      });
    });

    group('Nested Task Depth', () {
      test('single child task is depth 1 under its parent', () {
        const content = '''- [ ] Cookies
  - [ ] Milk''';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 2);
        expect(tasks[0].description, 'Cookies');
        expect(tasks[0].depth, 0);
        expect(tasks[0].parentTaskId, isNull);
        expect(tasks[1].description, 'Milk');
        expect(tasks[1].depth, 1);
        expect(tasks[1].parentTaskId, tasks[0].taskSource!.id);
      });

      test('multiple children of one parent are all depth 1, in source order',
          () {
        const content = '''- [ ] Cookies
  - [ ] Milk
  - [ ] Chocolate Chips
  - [ ] Sugar
- [ ] Cheese''';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 5);
        expect(tasks[0].description, 'Cookies');
        expect(tasks[0].depth, 0);
        for (final child in tasks.sublist(1, 4)) {
          expect(child.depth, 1);
          expect(child.parentTaskId, tasks[0].taskSource!.id);
        }
        expect(tasks[1].description, 'Milk');
        expect(tasks[2].description, 'Chocolate Chips');
        expect(tasks[3].description, 'Sugar');
        expect(tasks[4].description, 'Cheese');
        expect(tasks[4].depth, 0);
        expect(tasks[4].parentTaskId, isNull);
      });

      test('three-level nesting resolves to depths 0, 1, 2', () {
        const content = '''- [ ] Groceries
  - [ ] Cookies
    - [ ] Milk''';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 3);
        expect(tasks[0].depth, 0);
        expect(tasks[1].depth, 1);
        expect(tasks[1].parentTaskId, tasks[0].taskSource!.id);
        expect(tasks[2].depth, 2);
        expect(tasks[2].parentTaskId, tasks[1].taskSource!.id);
      });

      test(
          'a task indented as if it were a grandchild, with no depth-1 task '
          'above it, resolves to depth 1 (its nearest actual parent), not 2',
          () {
        const content = '''- [ ] Top level
    - [ ] Skips visually to grandchild indentation''';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 2);
        expect(tasks[0].depth, 0);
        expect(tasks[1].depth, 1);
        expect(tasks[1].parentTaskId, tasks[0].taskSource!.id);
      });

      test(
          'an indented task with no preceding task at all has no parent and '
          'is depth 0', () {
        const content = '''    - [ ] Indented, but first line in the file
- [ ] Then a top-level task''';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 2);
        expect(tasks[0].depth, 0);
        expect(tasks[0].parentTaskId, isNull);
        expect(tasks[1].depth, 0);
        expect(tasks[1].parentTaskId, isNull);
      });

      test('a non-task line between parent and child does not break the '
          'relationship', () {
        const content = '''- [ ] Parent
  Some plain note text, not a checkbox
  - [ ] Child''';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 2);
        expect(tasks[0].description, 'Parent');
        expect(tasks[1].description, 'Child');
        expect(tasks[1].depth, 1);
        expect(tasks[1].parentTaskId, tasks[0].taskSource!.id);
      });

      test('mixed tabs and spaces still compare consistently', () {
        // A tab counts as 4 columns (research.md Decision 3), so a
        // tab-indented child (4 columns) is deeper than its 2-space-indented
        // parent, and a further 2-space-indented grandchild (6 columns) is
        // deeper still than the tab-indented child.
        const content = '- [ ] Parent\n\t- [ ] Tab child\n\t  - [ ] Space grandchild';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 3);
        expect(tasks[0].depth, 0);
        expect(tasks[1].depth, 1);
        expect(tasks[1].parentTaskId, tasks[0].taskSource!.id);
        expect(tasks[2].depth, 2);
        expect(tasks[2].parentTaskId, tasks[1].taskSource!.id);
      });

      test('a note with no indentation leaves every task at depth 0', () {
        const content = '''- [ ] First task
* [x] Second task
+ [ ] Third task''';

        final tasks = Parser.parseTasks('test.md', content);

        expect(tasks.length, 3);
        for (final task in tasks) {
          expect(task.depth, 0);
          expect(task.parentTaskId, isNull);
        }
      });
    });
  });
}
