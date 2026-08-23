//import 'package:dart_markdown/dart_markdown.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/tasks/parsers/parser.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_parser.dart';
import 'package:obsi/src/core/tasks/task_source.dart';

class MarkdownParser extends Parser {
  MarkdownParser();

  @override
  List<Task> internalParseTasks(String fileName, String content,
      {int fileNumber = 0, String taskFilter = ""}) {
    Logger().i("Parsing markdown: $fileName");
    return _parseTasksByPattern(content,
        fileNumber: fileNumber, fileName: fileName, taskFilter: taskFilter);
  }

  int _skipSpaces(int i, String content) {
    while (i < content.length && (content[i] == ' ' || content[i] == '\t')) {
      i++;
    }
    return i;
  }

  int _skipLine(int i, String content) {
    while (i < content.length && content[i] != '\n') {
      i++;
    }
    if (i < content.length) {
      i++;
    }
    return i;
  }

  /// Validates if a character is a valid task completion marker
  bool _isValidCompletionMarker(String char) {
    return char != ' ';
    //char == 'x' || char == 'X' || char == '✓' || char == '✗';
  }

  /// Removes task filter from content with proper validation
  String _removeTaskFilter(String content, String filter) {
    if (filter.isEmpty) {
      return content;
    }

    // Only remove filter if it exists in the content
    if (content.contains(filter)) {
      return content.replaceFirst(filter, '');
    }

    return content;
  }

  /// Counts the width of the whitespace between [start] and [end] (exclusive),
  /// treating a space as 1 column and a tab as 4 columns, so indentation
  /// that mixes tabs and spaces still compares consistently (see
  /// research.md Decision 3).
  int _indentWidth(String content, int start, int end) {
    int width = 0;
    for (int j = start; j < end; j++) {
      width += content[j] == '\t' ? 4 : 1;
    }
    return width;
  }

  /// Parses tasks directly from string content character by character
  /// Looks for task patterns: - [, * [, + [ followed by status and content
  List<Task> _parseTasksByPattern(String content,
      {int fileNumber = 0, String fileName = "", String taskFilter = ""}) {
    List<Task> tasks = [];
    int i = 0;
    // Tracks the nesting stack for this file only: a task's parent is the
    // nearest preceding task (in source order) with a strictly lower
    // indentWidth. See contracts/depth_computation_contract.md.
    final List<(int, Task)> depthStack = [];

    while (i < content.length) {
      //print("Processing offset $i");
      String taskContent = '';
      TaskStatus taskStatus = TaskStatus.todo;
      int lineStart = i;
      i = _skipSpaces(i, content);
      int taskOffset = i;
      int indentWidth = _indentWidth(content, lineStart, taskOffset);

      // Check for task marker (-, *, +) with bounds checking
      if (i < content.length &&
          (content[i] == '-' || content[i] == '*' || content[i] == '+')) {
        i++;

        // Check for space after marker
        if (i < content.length && content[i] == ' ') {
          i++;

          // Check for opening bracket
          if (i < content.length && content[i] == '[') {
            i++;

            // Check task status with proper validation
            if (i < content.length) {
              if (content[i] == ' ') {
                taskStatus = TaskStatus.todo;
                i++;
              } else if (_isValidCompletionMarker(content[i])) {
                taskStatus = TaskStatus.done;
                i++;
              } else {
                // Invalid marker, skip this line
                i = _skipLine(i, content);
                continue;
              }
            } else {
              i = _skipLine(i, content);
              continue;
            }

            // Check for closing bracket
            if (i < content.length && content[i] == ']') {
              i++;
            } else {
              // Invalid task format, skip to next line
              i = _skipLine(i, content);
              continue;
            }

            // Skip spaces after bracket
            i = _skipSpaces(i, content);

            // Read task content until end of line
            while (i < content.length && content[i] != '\n') {
              taskContent += content[i];
              i++;
            }

            // Fix: Calculate correct task length
            int taskLength = i - taskOffset;

            // Fix: Properly handle task filter removal
            var contentWithoutFilter =
                _removeTaskFilter(taskContent, taskFilter);

            // Resolve this task's depth/parent from the stack before the
            // filter check below, so a task excluded by taskFilter still
            // correctly anchors the stack for any of its children that do
            // pass the filter - a child's depth must not depend on whether
            // its ancestors happen to also match the filter.
            while (depthStack.isNotEmpty && depthStack.last.$1 >= indentWidth) {
              depthStack.removeLast();
            }
            final newTask = TaskParser().build(contentWithoutFilter,
                status: taskStatus,
                taskSource: TaskSource(
                    fileNumber, fileName, taskOffset, taskLength));
            if (depthStack.isNotEmpty) {
              newTask.depth = depthStack.last.$2.depth + 1;
              newTask.parentTaskId = depthStack.last.$2.taskSource!.id;
            }
            depthStack.add((indentWidth, newTask));

            // if taskFilter is empty or task contains filter then add task
            if (taskFilter.isEmpty ||
                (taskFilter.isNotEmpty &&
                    contentWithoutFilter.length < taskContent.length)) {
              tasks.add(newTask);
              //print("Added task: ${tasks.last}");
            }
          }
        }
      }
      i = _skipLine(i, content);
    }
    return tasks;
  }
}
