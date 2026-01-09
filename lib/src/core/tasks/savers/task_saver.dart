import 'dart:io';

import 'package:logger/logger.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_parser.dart';
import 'package:obsi/src/core/storage/storage_interfaces.dart';
import 'package:obsi/src/core/tasks/task_source.dart';
import 'package:obsi/src/core/tasks/savers/task_note_saver.dart';

class TaskSaver {
  TasksFileStorage storage;
  TaskSaver(this.storage);

  Future<String> saveTaskNote(Task task) async {
    var taskNoteSaver = TaskNoteSaver();
    return taskNoteSaver.toTaskNoteString(task);
  }

  Future<String?> saveTasks(List<Task> tasks,
      {String? filePath,
      String dateTemplate = "yyyy-MM-dd",
      String taskFilter = "",
      String? saveMarker}) async {
    if (tasks[0].taskSource == null && filePath == null) {
      return null;
    }

    var fileName = filePath ?? tasks[0].taskSource!.fileName;
    var file = storage.getFile(fileName);
    var fileExists = await file.exists();
    if (!fileExists) {
      await file.create();
    }

    String savedContent = "";
    if (tasks[0].taskSource != null &&
        tasks[0].taskSource!.type == TaskType.taskNote) {
      savedContent = await saveTaskNote(tasks[0]);
    } else {
      var content = await file.readAsString();

      // If a marker is specified, find its position and use it as the offset
      if (saveMarker != null && saveMarker.isNotEmpty && filePath != null) {
        final insertPosition = _findMarkerInsertPosition(content, saveMarker);

        if (insertPosition != null) {
          tasks[0].taskSource = TaskSource(
            0,
            fileName,
            insertPosition,
            0,
            type: TaskType.markdown,
          );
        }
      }

      savedContent =
          _createNewContent(tasks, content, filePath, dateTemplate, taskFilter);
    }
    Logger().i("Content saved: $savedContent");
    await file.writeAsString(savedContent);
    return savedContent;
  }

  int? _findMarkerInsertPosition(String content, String marker) {
    final markerIndex = content.indexOf(marker);

    if (markerIndex == -1) {
      return null;
    }

    final markerEndIndex = markerIndex + marker.length;
    int insertPosition = markerEndIndex;

    // Skip newline after marker if present
    if (markerEndIndex < content.length && content[markerEndIndex] == '\n') {
      insertPosition = markerEndIndex + 1;
    }

    return insertPosition;
  }

  String _createNewContent(List<Task> tasks, String content, String? filePath,
      String dateTemplate, String taskFilter) {
    int taskOffset = tasks[0].taskSource == null
        ? content.length
        : tasks[0].taskSource!.offset;
    var taskLength =
        tasks[0].taskSource == null ? 0 : tasks[0].taskSource!.length;

    var beginningOfFileContent = content.substring(0, taskOffset);
    var endOfTask = taskOffset + taskLength;
    var endOfFileContent = content.substring(endOfTask);

    // If this is a new task then add it on a new line
    String serializedTask = filePath != null ? "\n" : "";
    for (var task in tasks) {
      serializedTask += TaskParser().toTaskString(task,
          dateTemplate: dateTemplate, taskFilter: taskFilter);
      if (tasks.length > 1) {
        serializedTask += "\n";
      }
    }

    var result = beginningOfFileContent + serializedTask + endOfFileContent;
    return result;
  }
}
