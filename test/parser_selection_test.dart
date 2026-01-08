import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/tasks/parsers/parser.dart';

void main() {
  group('Parser Selection', () {
    test('should use TaskNoteParser for YAML with task tag', () {
      const content = '''---
status: open
priority: normal
tags:
  - task
---

Task content here''';

      final tasks = Parser.parseTasks('test.md', content);
      expect(tasks.length, equals(1));
      expect(tasks[0].description, contains('Task content here'));
    });

    test('should use MarkdownParser for YAML without task tag', () {
      const content = '''---
priority: normal
tags:
  - other
  - random
---

This should not be treated as a task note''';

      final tasks = Parser.parseTasks('test.md', content);
      expect(tasks.length, equals(0)); // No markdown tasks found
    });

    test('should use MarkdownParser for YAML without tags section', () {
      const content = '''---
priority: normal
---

This should not be treated as a task note''';

      final tasks = Parser.parseTasks('test.md', content);
      expect(tasks.length, equals(0)); // No markdown tasks found
    });

    test('should use MarkdownParser for content without YAML', () {
      const content = '''# Regular Markdown

- [ ] This is a regular markdown task
- [x] This is completed''';

      final tasks = Parser.parseTasks('test.md', content);
      expect(tasks.length, equals(2)); // Two markdown tasks found
    });

    test('should use TaskNoteParser when task tag is among multiple tags', () {
      const content = '''---
status: open
priority: high
tags:
  - work
  - task
  - urgent
---

Task with multiple tags''';

      final tasks = Parser.parseTasks('test.md', content);
      expect(tasks.length, equals(1));
      expect(tasks[0].tags, contains('task'));
      expect(tasks[0].tags, contains('work'));
      expect(tasks[0].tags, contains('urgent'));
    });

    test('should use MarkdownParser for YAML with empty tags list', () {
      const content = '''---
priority: normal
tags:
---

This should not be treated as a task note''';

      final tasks = Parser.parseTasks('test.md', content);
      expect(tasks.length, equals(0)); // No tasks found
    });

    test('should use TaskNoteParser for YAML with task', () {
      const content = '''---
status: open
---
This should not be treated as a task note''';

      final tasks = Parser.parseTasks('test.md', content);
      expect(tasks.length, equals(1)); // No tasks found
    });

    test('should be case-sensitive for task tag', () {
      const content = '''---
status: open
priority: normal
tags:
  - Task
  - TASK
---

Should not match with different case''';

      final tasks = Parser.parseTasks('test.md', content);
      expect(tasks.length, equals(1)); // No tasks found - case sensitive
    });
  });
}
