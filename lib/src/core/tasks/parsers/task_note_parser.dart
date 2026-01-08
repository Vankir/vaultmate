import 'package:logger/logger.dart';
import 'package:obsi/src/core/tasks/parsers/parser.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_source.dart';
import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart' show Tuple2;

class TaskNoteParser extends Parser {
  TaskNoteParser();

  @override
  List<Task> internalParseTasks(String fileName, String content,
      {int fileNumber = 0, String taskFilter = ""}) {
    Logger().i("Parsing task note: $fileName");
    Task? task = parseTaskNote(fileName, content,
        fileNumber: fileNumber, taskFilter: taskFilter);
    return task != null ? [task] : [];
  }

  /// Parses status from YAML content
  static TaskStatus parseStatus(String yamlContent) {
    final statusMatch =
        RegExp(r'^status:\s+(\S+)', multiLine: true).firstMatch(yamlContent);
    if (statusMatch != null) {
      switch (statusMatch.group(1)?.toLowerCase()) {
        case 'done':
          return TaskStatus.done;
        case 'in-progress':
          return TaskStatus.inprogress;
        case 'cancelled':
          return TaskStatus.cancelled;
        default:
          return TaskStatus.todo;
      }
    }

    throw Exception("No status found in YAML content");
  }

  /// Parses priority from YAML content
  TaskPriority _parsePriority(String yamlContent) {
    final priorityMatch =
        RegExp(r'^priority:\s+(\S+)', multiLine: true).firstMatch(yamlContent);
    if (priorityMatch != null) {
      switch (priorityMatch.group(1)?.toLowerCase()) {
        case 'lowest':
          return TaskPriority.lowest;
        case 'low':
          return TaskPriority.low;
        case 'medium':
          return TaskPriority.medium;
        case 'high':
          return TaskPriority.high;
        case 'highest':
          return TaskPriority.highest;
        default:
          return TaskPriority.normal;
      }
    }
    return TaskPriority.normal;
  }

  /// Parses scheduled date from YAML content
  /// Returns a Map with 'dateTime' and 'hasTime' keys
  /// Supports both date-only (2025-11-03) and date-with-time (2025-11-03N19:00:00) formats
  Map<String, dynamic> _parseScheduledDate(String yamlContent) {
    final scheduledIsoMatch =
        RegExp(r'^scheduled:\s+(\d{4}-\d{2}-\d{2}T[^\s]+)', multiLine: true)
            .firstMatch(yamlContent);
    if (scheduledIsoMatch != null) {
      final dateTime = DateTime.tryParse(scheduledIsoMatch.group(1)!);
      return {'dateTime': dateTime, 'hasTime': dateTime != null};
    }

    // Try to match date with time first: 2025-11-03N19:00:00
    final scheduledWithTimeMatch = RegExp(
            r'^scheduled:\s+(\d{4}-\d{2}-\d{2})N(\d{2}:\d{2}:\d{2})',
            multiLine: true)
        .firstMatch(yamlContent);

    if (scheduledWithTimeMatch != null) {
      final dateStr = scheduledWithTimeMatch.group(1)!;
      final timeStr = scheduledWithTimeMatch.group(2)!;
      final dateTimeStr = '${dateStr}T$timeStr';
      var dateTime = DateTime.tryParse(dateTimeStr);
      return {'dateTime': dateTime, 'hasTime': dateTime != null};
    }

    // Try to match date only: 2025-11-03
    final scheduledMatch =
        RegExp(r'^scheduled:\s+(\d{4}-\d{2}-\d{2})(?:\s|$)', multiLine: true)
            .firstMatch(yamlContent);
    if (scheduledMatch != null) {
      final dateTime = DateTime.tryParse(scheduledMatch.group(1)!);
      return {'dateTime': dateTime, 'hasTime': false};
    }

    return {'dateTime': null, 'hasTime': false};
  }

  /// Parses created date from YAML content
  DateTime? _parseCreatedDate(String yamlContent) {
    final createdMatch =
        RegExp(r'^dateCreated:\s+(\d{4}-\d{2}-\d{2}T[^\s]+)', multiLine: true)
            .firstMatch(yamlContent);
    if (createdMatch != null) {
      return DateTime.tryParse(createdMatch.group(1)!);
    }
    return null;
  }

  /// Parses modified date from YAML content
  DateTime? _parseModifiedDate(String yamlContent) {
    final modifiedMatch =
        RegExp(r'^dateModified:\s+(\d{4}-\d{2}-\d{2}T[^\s]+)', multiLine: true)
            .firstMatch(yamlContent);
    if (modifiedMatch != null) {
      return DateTime.tryParse(modifiedMatch.group(1)!);
    }
    return null;
  }

  /// Parses tags from YAML content
  static List<String> parseTags(String yamlContent) {
    final tags = <String>[];

    // Check for inline format first: tags: value (not starting with -)
    final inlineTagsMatch = RegExp(r'^tags:\s+([^-\s]\S*)\s*$', multiLine: true)
        .firstMatch(yamlContent);
    if (inlineTagsMatch != null) {
      final tag = inlineTagsMatch.group(1)!.trim();
      if (tag.isNotEmpty) {
        tags.add(tag);
      }
      return tags;
    }

    // Find the tags section (list format)
    final tagsMatch =
        RegExp(r'^tags:\s*$', multiLine: true).firstMatch(yamlContent);
    if (tagsMatch == null) {
      return tags;
    }

    // Get the position after "tags:"
    final tagsStart = tagsMatch.end;
    final lines = yamlContent.substring(tagsStart).split('\n');

    // Parse tag items (lines starting with "  - ")
    for (final line in lines) {
      final tagMatch = RegExp(r'^\s*-\s+(.+)\s*$').firstMatch(line.trim());
      if (tagMatch != null) {
        final tag = tagMatch.group(1)!.trim();
        if (tag.isNotEmpty) {
          tags.add(tag);
        }
      } else if (line.trim().isNotEmpty && !line.startsWith('  ')) {
        // Stop parsing if we hit a non-tag line that's not indented
        break;
      }
    }

    return tags;
  }

  /// Parses task note and creates a Task object from YAML front matter
  /// Returns Task object or null if invalid
  Task? parseTaskNote(String fileName, String content,
      {int fileNumber = 0, String taskFilter = "", String? filePath}) {
    if (content.isEmpty) {
      return null;
    }

    // Parse using existing validation logic
    final result = parseTaskNoteWithContent(fileName, content,
        fileNumber: fileNumber, taskFilter: taskFilter);
    if (result == null) {
      return null;
    }

    // Extract metadata from YAML
    final yamlContent = result.yamlContent;

    // Parse metadata from YAML
    final status = parseStatus(yamlContent);
    final priority = _parsePriority(yamlContent);
    final scheduledResult = _parseScheduledDate(yamlContent);
    final scheduled = scheduledResult['dateTime'] as DateTime?;
    final scheduledTime = scheduledResult['hasTime'] as bool;
    final dateCreated = _parseCreatedDate(yamlContent);
    final tags = parseTags(yamlContent);

    // Create TaskSource
    final taskSource = TaskSource(fileNumber, fileName, 0, content.length,
        type: TaskType.taskNote);

    // Use the task content as description, or filename if no content
    String description = result.taskContent.isNotEmpty
        ? result.taskContent
        : p.basenameWithoutExtension(fileName);

    // Add tags to description if any exist
    if (tags.isNotEmpty) {
      final tagString = tags.map((tag) => '#$tag').join(' ');
      description = '$description $tagString'.trim();
    }

    // Create and return Task
    return Task(
      description,
      status: status,
      priority: priority,
      created: dateCreated,
      scheduled: scheduled,
      scheduledTime: scheduledTime,
      taskSource: taskSource,
    );
  }

  static Tuple2<int, String> extractYamlStart(String content) {
    // Check if content starts with YAML front matter delimiter
    if (!content.startsWith('---')) {
      return Tuple2<int, String>(0, '');
    }

    // Find the closing delimiter
    int firstDelimiterEnd = content.indexOf('\n');
    if (firstDelimiterEnd == -1) {
      return Tuple2<int, String>(0, '');
    }

    int closingDelimiterStart = content.indexOf('\n---', firstDelimiterEnd);
    if (closingDelimiterStart == -1) {
      return Tuple2<int, String>(0, '');
    }

    // Extract YAML content between delimiters
    String yamlContent =
        content.substring(firstDelimiterEnd + 1, closingDelimiterStart);

    return Tuple2<int, String>(closingDelimiterStart + 4, yamlContent);
  }

  /// Parses task note and extracts both YAML metadata and content
  /// Returns TaskNoteResult with metadata and content, or null if invalid
  TaskNoteResult? parseTaskNoteWithContent(String fileName, String content,
      {int fileNumber = 0, String taskFilter = ""}) {
    if (content.isEmpty) {
      return null;
    }

    Tuple2<int, String> extractedYaml = extractYamlStart(content);
    if (extractedYaml.item1 == 0) {
      return null;
    }

    // Extract content after closing delimiter
    int contentStart = extractedYaml.item1; // Skip "\n---"
    String taskContent = '';

    if (contentStart < content.length) {
      taskContent = content.substring(contentStart).trim();
    }

    return TaskNoteResult(
      yamlContent: extractedYaml.item2,
      taskContent: taskContent,
      fileName: fileName,
      fileNumber: fileNumber,
    );
  }
}

/// Result class for parsed task note with YAML metadata and content
class TaskNoteResult {
  final String yamlContent;
  final String taskContent;
  final String fileName;
  final int fileNumber;

  TaskNoteResult({
    required this.yamlContent,
    required this.taskContent,
    required this.fileName,
    required this.fileNumber,
  });

  @override
  String toString() {
    return 'TaskNoteResult(fileName: $fileName, fileNumber: $fileNumber, yamlContent: ${yamlContent.length} chars, taskContent: ${taskContent.length} chars)';
  }
}
