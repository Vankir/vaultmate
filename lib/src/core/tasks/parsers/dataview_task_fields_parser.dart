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
      final key =
          (match.group(1) ?? match.group(3) ?? '').trim().toLowerCase();
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
