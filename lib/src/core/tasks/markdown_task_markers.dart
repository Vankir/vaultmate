import 'package:obsi/src/core/tasks/task.dart';

class MarkdownTaskMarkers {
  static const Map<TaskStatus, String> taskStatuses = {
    TaskStatus.todo: "[ ]",
    TaskStatus.inprogress: "[/]",
    TaskStatus.done: "[x]",
    TaskStatus.cancelled: "[-]"
  };

  static var createdDateMarker = '➕';

  static var recurringDateMarker = '🔁';

  static var dueDateMarker = '📅';

  static var startDateMarker = "🛫";

  static var scheduledDateMarker = '⏳';

  static var scheduledTimeMarker = '(@';

  static var doneDateMarker = '✅';

  static var cancelledDateMarker = '❌';

  static var priorities = {
    "⏬": TaskPriority.lowest,
    "🔽": TaskPriority.low,
    "🔼": TaskPriority.medium,
    "⏫": TaskPriority.high,
    "🔺": TaskPriority.highest,
  };

  String getPriorityMarker(TaskPriority priority) {
    return priorities.entries
        .firstWhere((element) => element.value == priority ? true : false,
            orElse: () => const MapEntry("", TaskPriority.normal))
        .key;
  }
}
