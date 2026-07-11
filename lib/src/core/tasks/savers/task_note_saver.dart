import 'package:intl/intl.dart';
import 'package:obsi/src/core/tasks/task.dart';

/// Saves Task objects in TaskNote format with YAML front matter
class TaskNoteSaver {
  TaskNoteSaver();

  /// Converts a Task to TaskNote format with YAML front matter
  /// Returns the complete file content as a string
  String toTaskNoteString(Task task) {
    String taskContent = """---
status: ${_statusToString(task.status)}
priority: ${_priorityToString(task.priority)}
scheduled: ${_formatScheduledDate(task.scheduled, task.scheduledTime)}
dateCreated: ${_formatDateTime(task.created)}
dateModified: ${_formatDateTime(DateTime.now())}
tags:
  - ${task.tags.join('\n  - ')}
---
""";

    if (task.description != null && task.description!.isNotEmpty) {
      taskContent += "\n";
      taskContent += task.description!;
    }

    return taskContent;
  }

  /// Converts TaskStatus to YAML string value
  String _statusToString(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return 'open';
      case TaskStatus.done:
        return 'done';
      case TaskStatus.inprogress:
        return 'in-progress';
      case TaskStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Converts TaskPriority to YAML string value
  String _priorityToString(TaskPriority priority) {
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

  /// Formats scheduled date as YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS
  String _formatScheduledDate(DateTime? date, bool includeTime) {
    if (date == null) {
      return '';
    }

    if (includeTime) {
      // Format as YYYY-MM-DDNHH:MM:SS
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final timeStr = DateFormat('HH:mm:ss').format(date);
      return '${dateStr}T$timeStr';
    } else {
      // Format as YYYY-MM-DD
      return DateFormat('yyyy-MM-dd').format(date);
    }
  }

  /// Formats datetime as ISO 8601 with timezone
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }
    return dateTime.toIso8601String();
  }
}
