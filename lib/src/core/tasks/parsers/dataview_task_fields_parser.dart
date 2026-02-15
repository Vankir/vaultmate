import 'package:intl/intl.dart';
import 'package:obsi/src/core/tasks/markdown_task_markers.dart';
import 'package:obsi/src/core/tasks/task.dart';

class DataviewTaskFieldsParser {
  static final RegExp _dataviewFieldPattern = RegExp(
      r'\[([A-Za-z][A-Za-z0-9_-]*)\s*::\s*([^\]\n]+)\]|\(([A-Za-z][A-Za-z0-9_-]*)\s*::\s*([^\)\n]+)\)');

  static const Set<String> _supportedDataviewFields = {
    'created',
    'scheduled',
    'start',
    'due',
    'completion',
    'cancelled',
    'priority',
    'repeat',
  };

  DataviewParseResult extract(String source) {
    DateTime? created;
    DateTime? scheduled;
    DateTime? start;
    DateTime? due;
    DateTime? completion;
    DateTime? cancelled;
    TaskPriority? priority;
    String? repeat;

    final cleaned = source.replaceAllMapped(_dataviewFieldPattern, (match) {
      final key = (match.group(1) ?? match.group(3) ?? '').trim().toLowerCase();
      final value = (match.group(2) ?? match.group(4) ?? '').trim();

      if (!_supportedDataviewFields.contains(key)) {
        return match.group(0)!;
      }

      switch (key) {
        case 'created':
          created = _parseDataviewDateValue(value) ?? created;
          break;
        case 'scheduled':
          scheduled = _parseDataviewDateValue(value) ?? scheduled;
          break;
        case 'start':
          start = _parseDataviewDateValue(value) ?? start;
          break;
        case 'due':
          due = _parseDataviewDateValue(value) ?? due;
          break;
        case 'completion':
          completion = _parseDataviewDateValue(value) ?? completion;
          break;
        case 'cancelled':
          cancelled = _parseDataviewDateValue(value) ?? cancelled;
          break;
        case 'priority':
          priority = _parseDataviewPriority(value);
          break;
        case 'repeat':
          repeat = value;
          break;
      }

      return '';
    });

    final normalized = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return DataviewParseResult(
      cleanedText: normalized,
      created: created,
      scheduled: scheduled,
      start: start,
      due: due,
      completion: completion,
      cancelled: cancelled,
      priority: priority,
      repeat: repeat,
    );
  }

  String toTaskString(Task task,
      {String dateTemplate = "yyyy-MM-dd", String taskFilter = ""}) {
    var serializedTask = "- ${MarkdownTaskMarkers.taskStatuses[task.status]} ";
    if (task.description != null) {
      serializedTask += task.description!;
      if (taskFilter.isNotEmpty) {
        serializedTask += " $taskFilter";
      }
    }

    if (task.tags.isNotEmpty) {
      final tagsString = task.tags.map((tag) => '#$tag').join(' ');
      serializedTask += ' $tagsString';
    }

    serializedTask += _saveDataviewField(
        'created',
        task.created == null
            ? null
            : _formatDataviewDate(task.created!, false,
                dateTemplate: dateTemplate));
    serializedTask += _saveDataviewField(
        'completion',
        task.done == null
            ? null
            : _formatDataviewDate(task.done!, false,
                dateTemplate: dateTemplate));
    serializedTask += _saveDataviewField(
        'cancelled',
        task.cancelled == null
            ? null
            : _formatDataviewDate(task.cancelled!, false,
                dateTemplate: dateTemplate));
    serializedTask += _saveDataviewField(
        'due',
        task.due == null
            ? null
            : _formatDataviewDate(task.due!, false,
                dateTemplate: dateTemplate));
    serializedTask += _saveDataviewField(
        'start',
        task.start == null
            ? null
            : _formatDataviewDate(task.start!, false,
                dateTemplate: dateTemplate));
    serializedTask += _saveDataviewField(
        'scheduled',
        task.scheduled == null
            ? null
            : _formatDataviewDate(task.scheduled!, task.scheduledTime,
                dateTemplate: dateTemplate));

    if (task.priority != TaskPriority.normal) {
      serializedTask += _saveDataviewField(
          'priority', _priorityToDataviewValue(task.priority));
    }

    if (task.recurrenceRule != null && task.recurrenceRule!.isNotEmpty) {
      serializedTask += _saveDataviewField('repeat', task.recurrenceRule);
    }

    return serializedTask;
  }

  bool _hasExplicitTime(String rawDate) {
    return rawDate.contains(':');
  }

  DateTime? _parseDataviewDateValue(String value, {bool forceTime = false}) {
    final normalized = value.trim();
    final parsedDate = DateTime.tryParse(normalized);
    if (parsedDate == null) {
      return null;
    }

    if (forceTime || _hasExplicitTime(normalized)) {
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
          parsedDate.hour, parsedDate.minute, 1);
    }

    return parsedDate;
  }

  TaskPriority _parseDataviewPriority(String value) {
    switch (value.trim().toLowerCase()) {
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

  String _priorityToDataviewValue(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.lowest:
        return 'lowest';
      case TaskPriority.low:
        return 'low';
      case TaskPriority.normal:
        return 'normal';
      case TaskPriority.medium:
        return 'medium';
      case TaskPriority.high:
        return 'high';
      case TaskPriority.highest:
        return 'highest';
    }
  }

  String _formatDataviewDate(DateTime date, bool includeTime,
      {String dateTemplate = 'yyyy-MM-dd'}) {
    if (!includeTime) {
      return DateFormat(dateTemplate).format(date);
    }
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(date);
  }

  String _saveDataviewField(String key, String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    return ' [$key:: $value]';
  }
}

class DataviewParseResult {
  final String cleanedText;
  final DateTime? created;
  final DateTime? scheduled;
  final DateTime? start;
  final DateTime? due;
  final DateTime? completion;
  final DateTime? cancelled;
  final TaskPriority? priority;
  final String? repeat;

  const DataviewParseResult({
    required this.cleanedText,
    this.created,
    this.scheduled,
    this.start,
    this.due,
    this.completion,
    this.cancelled,
    this.priority,
    this.repeat,
  });
}
