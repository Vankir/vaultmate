import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/tasks/markdown_task_markers.dart';
import 'package:obsi/src/core/tasks/parsers/dataview_task_fields_parser.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_source.dart';
import 'package:tuple/tuple.dart';

class TaskParser extends MarkdownTaskMarkers {
  static const taskFeaturePattern = r'\[[^\]]*\]';
  final DataviewTaskFieldsParser _dataviewParser = DataviewTaskFieldsParser();

  TaskStatus _getStatus(source) {
    var statuses = {
      r'\[[A-Za-z]\]': TaskStatus.done,
      r'\[/\]': TaskStatus.inprogress,
      r'\[-\]': TaskStatus.cancelled
    };

    var found = statuses.entries.firstWhere(
        (element) => source.contains(RegExp(element.key)),
        orElse: () => const MapEntry("", TaskStatus.todo));
    return found.value;
  }

//pattern for time is either (@yyyy-MM-dd HH:mm) or (@HH:mm)
  Tuple2<DateTime?, String> _getScheduledDateTimeInReminderFormat(
      String source) {
    final RegExp timeRegex =
        RegExp(r'\(@(\d{4}-\d{2}-\d{2} )?([01]\d|2[0-3]):([0-5]\d)\)');
    final match = timeRegex.firstMatch(source);

    if (match != null) {
      DateTime dateTime;
      if (match.group(1) != null) {
        dateTime = DateFormat('yyyy-MM-dd HH:mm')
            .parse('${match.group(1)}${match.group(2)}:${match.group(3)}');
      } else {
        dateTime = DateTime(
            0, 0, 0, int.parse(match.group(2)!), int.parse(match.group(3)!));
      }

      final updatedSource = source.replaceFirst(timeRegex, '');
      return Tuple2(dateTime, updatedSource);
    }

    return Tuple2(null, source);
  }

  /// Search for priority marker and if found it returns priority and found substring
  ///
  Tuple2<TaskPriority, String> _getPriority(source) {
    var found = MarkdownTaskMarkers.priorities.entries.firstWhere(
        (element) => source.contains(element.key),
        orElse: () => const MapEntry("", TaskPriority.normal));
    return Tuple2(found.value, found.key);
  }

  int _findFirstSpaceOrNewStringMarker(String source, int start) {
    var space = source.indexOf(' ', start);
    var newString = source.indexOf('\n', start);

    int end = -1;

    if (space >= 0) {
      if (newString >= 0) {
        end = space < newString ? space : newString;
      } else {
        end = space;
      }
    } else {
      end = newString;
    }

    end = end < 0 ? source.length : end;
    return end;
  }

  bool _isValidTime(String input) {
    final RegExp timeRegex = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$');
    return timeRegex.hasMatch(input.trim());
  }

  /// Search for marker of reccurant task and if found it substring after marker
  Tuple2<String?, String> _extractRecurrenceRuleAfterMarker(
      String source, String marker) {
    var markerIndex = source.indexOf(marker);

    // Marker is not found or string is too short to be a valid recurrence rule
    if (markerIndex < 0 || markerIndex >= source.length - 2) {
      return Tuple2(null, source);
    }

    // Find the first symbol after marker which is not a space
    var start = source.indexOf(RegExp(r'[^\s]'), markerIndex + marker.length);
    if (start < 0 || start >= source.length - 2) {
      return Tuple2(null, source);
    }

    // Find the end of the recurrence rule
    var end = source.indexOf(RegExp(r'[^\w\s]'), start);
    if (end == -1) {
      end = source.length;
    }

    var recurrenceRule = source.substring(start, end).trim();
    var res = source.replaceRange(markerIndex, end, '');
    return Tuple2(recurrenceRule, res);
  }

  /// Search for marker and if found it return date and substring without marker and date
  Tuple2<DateTime?, String> _extractDateAfterMarker(
      String source, String marker,
      {bool tryReadTime = false}) {
    var markerIndex = source.indexOf(marker);

    //marker is not found or string is too short to be a valid date
    if (markerIndex < 0 || markerIndex >= source.length - 2) {
      return Tuple2(null, source);
    }

    //find the first symbol after marker which is not space
    var start = source.indexOf(RegExp(r'[^\s]'), markerIndex + marker.length);
    if (start < 0 || start >= source.length - 2) {
      return Tuple2(null, source);
    }
    var end = _findFirstSpaceOrNewStringMarker(source, start);
    var timeInitialized = false;
    if (tryReadTime && end + 1 < source.length) {
      var startIndex = end + 1;
      var newEnd = _findFirstSpaceOrNewStringMarker(source, startIndex);
      var probablyTime = source.substring(startIndex, newEnd);
      if (_isValidTime(probablyTime)) {
        end = newEnd;
        timeInitialized = true;
      }
    }

    var dateSubstring = source.substring(start, end);
    var date = DateTime.tryParse(dateSubstring);
    if (date != null && timeInitialized) {
      //set marker that time is pointed out for this file because no way to determine if time is set to 00:00 or not set all
      //when 1 second is set it is used as a marker that use set time (not only date)
      date = date.add(const Duration(seconds: 1));
    }

    var res = date != null ? source.replaceRange(markerIndex, end, '') : source;
    return Tuple2(date, res);
  }

  /// Extracts time in HH:MM format from the beginning of the text
  /// Returns Tuple with DateTime (year 0 if no date) and remaining text
  Tuple2<DateTime?, String> _extractTimeFromBeginning(String source) {
    final RegExp timeRegex = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)\s+(.*)$');
    final match = timeRegex.firstMatch(source.trim());

    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final remainingText = match.group(3)!;
      final dateTime = DateTime(0, 0, 0, hour, minute);
      return Tuple2(dateTime, remainingText);
    }

    return Tuple2(null, source);
  }

  Tuple2<TaskStatus, String> _extractTaskFeature(String source) {
    String textOnly;

    var closeBracket = source.indexOf(']');

    //find the first symbol after marker which is not space
    var start = source.indexOf(RegExp(r'[^\s]'), closeBracket + 1);

    textOnly = source.substring(start);
    var featureOnly = source.substring(0, closeBracket + 1);
    TaskStatus status = _getStatus(featureOnly);
    return Tuple2(status, textOnly);
  }

  Task _fromString(TaskStatus? status, String source,
      {TaskSource? taskSource}) {
    String textOnly;
    var dataview = DataviewParseResult(cleanedText: '');
    if (status == null) {
      var taskFeature = _extractTaskFeature(source);
      status = taskFeature.item1;
      textOnly = taskFeature.item2;
    } else {
      textOnly = source;
    }

    // Try to extract time from the beginning (HH:MM format)
    var timeFromBeginning = _extractTimeFromBeginning(textOnly);
    DateTime? timeAtBeginning = timeFromBeginning.item1;
    if (timeAtBeginning != null) {
      textOnly = timeFromBeginning.item2;
    }

    var priority = _getPriority(source);
    textOnly = textOnly.replaceFirst(priority.item2, '');

    var createdDate = _extractDateAfterMarker(
        textOnly, MarkdownTaskMarkers.createdDateMarker);
    textOnly = createdDate.item2;

    var dueDate =
        _extractDateAfterMarker(textOnly, MarkdownTaskMarkers.dueDateMarker);
    textOnly = dueDate.item2;

    var startDate =
        _extractDateAfterMarker(textOnly, MarkdownTaskMarkers.startDateMarker);
    textOnly = startDate.item2;

    var scheduledDateRes = _extractDateAfterMarker(
        textOnly, MarkdownTaskMarkers.scheduledDateMarker,
        tryReadTime: true);
    textOnly = scheduledDateRes.item2;

    DateTime? scheduledDateTime = scheduledDateRes.item1;

    // scheduled time could be set directly in scheduled date, if so then no need to find it separately
    if (!(scheduledDateRes.item1 != null &&
        scheduledDateRes.item1!.second == 1)) {
      var scheduledTimeInReminderFormat =
          _getScheduledDateTimeInReminderFormat(textOnly);
      //if there is time set in task in format (@HH:mm) then it is used as a marker that time is set
      //if there is not date but there is time then this is incorrect format and no schedule is set
      if (scheduledTimeInReminderFormat.item1 != null) {
        if (!(scheduledDateRes.item1 == null &&
            scheduledTimeInReminderFormat.item1?.year == -1)) {
          scheduledDateTime = DateTime(
              scheduledDateRes.item1 == null
                  ? scheduledTimeInReminderFormat.item1!.year
                  : scheduledDateRes.item1!.year,
              scheduledDateRes.item1 == null
                  ? scheduledTimeInReminderFormat.item1!.month
                  : scheduledDateRes.item1!.month,
              scheduledDateRes.item1 == null
                  ? scheduledTimeInReminderFormat.item1!.day
                  : scheduledDateRes.item1!.day,
              scheduledTimeInReminderFormat.item1!.hour,
              scheduledTimeInReminderFormat.item1!.minute,
              1);
          textOnly = scheduledTimeInReminderFormat.item2;
        }
      } else if (timeAtBeginning != null) {
        // If no (@HH:mm) format found, check if time was extracted from beginning
        // Only apply if there's a scheduled date
        if (scheduledDateRes.item1 != null) {
          scheduledDateTime = DateTime(
              scheduledDateRes.item1!.year,
              scheduledDateRes.item1!.month,
              scheduledDateRes.item1!.day,
              timeAtBeginning.hour,
              timeAtBeginning.minute,
              1);
        }
      }
    }

    var doneDate =
        _extractDateAfterMarker(textOnly, MarkdownTaskMarkers.doneDateMarker);
    textOnly = doneDate.item2;

    var cancelledDate = _extractDateAfterMarker(
        textOnly, MarkdownTaskMarkers.cancelledDateMarker);
    textOnly = cancelledDate.item2;
    var recurranceRule = _extractRecurrenceRuleAfterMarker(
        textOnly, MarkdownTaskMarkers.recurringDateMarker);
    textOnly = recurranceRule.item2;

    final parsedWithEmojiFormat = priority.item2.isNotEmpty ||
        createdDate.item1 != null ||
        dueDate.item1 != null ||
        startDate.item1 != null ||
        scheduledDateTime != null ||
        doneDate.item1 != null ||
        cancelledDate.item1 != null ||
        recurranceRule.item1 != null;

    if (!parsedWithEmojiFormat) {
      dataview = _dataviewParser.extract(textOnly);
      textOnly = dataview.cleanedText;
    }

    final resolvedPriority = dataview.priority ?? priority.item1;

    final resolvedScheduled = scheduledDateTime ?? dataview.scheduled;

    return Task(textOnly.trim(),
        status: status,
        priority: resolvedPriority,
        created: createdDate.item1 ?? dataview.created,
        due: dueDate.item1 ?? dataview.due,
        start: startDate.item1 ?? dataview.start,
        scheduled: resolvedScheduled,
        scheduledTime: resolvedScheduled?.second == 1,
        done: doneDate.item1 ?? dataview.completion,
        cancelled: cancelledDate.item1 ?? dataview.cancelled,
        recurranceRule: recurranceRule.item1 ?? dataview.repeat,
        taskSource: taskSource);
  }

  Task build(String contentSource,
      {TaskStatus? status, TaskSource? taskSource}) {
    return _fromString(status, contentSource, taskSource: taskSource);
  }

  String _saveDate(String marker, String inputFormat, DateTime? date) {
    if (date == null) {
      return "";
    }

    // var format = inputFormat;
    // // this is marker to save also time
    // if (date.second == 1) {
    //   format += " HH:mm";
    // }
    var formatedDate = DateFormat(inputFormat).format(date);
    String res = " $marker $formatedDate";
    return res;
  }

  String toTaskString(Task task,
      {String dateTemplate = "yyyy-MM-dd",
      String taskFilter = "",
      bool dataViewDefaultMarkdownFormat = false}) {
    if (dataViewDefaultMarkdownFormat) {
      return _dataviewParser.toTaskString(task,
          dateTemplate: dateTemplate, taskFilter: taskFilter);
    }

    var serializedTask = "- ${MarkdownTaskMarkers.taskStatuses[task.status]} ";
    if (task.description != null) {
      serializedTask += task.description!;
      if (taskFilter.isNotEmpty) {
        serializedTask += " $taskFilter";
      }
    }

    // Add tags as hashtags
    if (task.tags.isNotEmpty) {
      final tagsString = task.tags.map((tag) => '#$tag').join(' ');
      serializedTask += ' $tagsString';
    }

    if (task.scheduled != null && task.scheduledTime) {
      var time = DateFormat("HH:mm").format(task.scheduled!);
      serializedTask += " (@$time)";
    }

    serializedTask += getPriorityMarker(task.priority);

    serializedTask += _saveDate(
        MarkdownTaskMarkers.createdDateMarker, dateTemplate, task.created);

    serializedTask +=
        _saveDate(MarkdownTaskMarkers.doneDateMarker, dateTemplate, task.done);
    serializedTask += _saveDate(
        MarkdownTaskMarkers.cancelledDateMarker, dateTemplate, task.cancelled);
    serializedTask +=
        _saveDate(MarkdownTaskMarkers.dueDateMarker, dateTemplate, task.due);

    serializedTask += _saveDate(
        MarkdownTaskMarkers.startDateMarker, dateTemplate, task.start);

    serializedTask += _saveDate(
        MarkdownTaskMarkers.scheduledDateMarker, dateTemplate, task.scheduled);

    if (task.recurrenceRule != null) {
      serializedTask +=
          " ${MarkdownTaskMarkers.recurringDateMarker} ${task.recurrenceRule}";
    }
    Logger().d("TaskParser.toTaskString: serializedTask: $serializedTask");
    return serializedTask;
  }

  DateTime? _setScheduledTime(DateTime? dateTime, bool scheduledTime) {
    if (dateTime == null) return null;

    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      scheduledTime ? 1 : 0, // Set seconds to 0
      0, // Set milliseconds to 0 (optional)
    );
  }
}
