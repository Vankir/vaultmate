import 'dart:io';
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/storage/storage_interfaces.dart';
import 'package:obsi/src/core/tasks/parsers/parser.dart';
import 'package:obsi/src/core/tasks/reccurent_task.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/savers/task_saver.dart';
import 'package:obsi/src/core/tasks/task_worker.dart';
import 'package:tuple/tuple.dart';

enum TaskManagerStatus { none, loading, loaded }

enum TaskScheduleState { none, dueToday, overdue }

extension SplitMatch<T> on List<T> {
  Tuple2<List<T>, List<T>> splitMatch(bool Function(T element) matchFunction) {
    final listMatch = Tuple2<List<T>, List<T>>([], []);

    for (final element in this) {
      if (matchFunction(element)) {
        listMatch.item1.add(element);
      } else {
        listMatch.item2.add(element);
      }
    }

    return listMatch;
  }
}

class TaskManager with ChangeNotifier {
  List<Task> _tasks = [];
  List<String> _allTags = [];
  String _path = "";
  String get vaultPath => _path;
  TaskManagerStatus status = TaskManagerStatus.none;
  List<Task> get tasks {
    var newList = _tasks.toList();
    //_sort(newList);
    return newList;
  }

  /// Returns all unique tags from all loaded tasks
  List<String> get allTags {
    final tags = List<String>.from(_allTags);
    return tags;
  }

  String dateTemplate;
  bool todoOnly;
  String _taskFilter;
  DateTime? forDateOnly;
  Object? lastError;
  TasksFileStorage storage;
  String _vaultName = "";
  bool includeDueTasksInToday = true;

  // String get vaultName {
  //   if (_vaultName.isEmpty) {
  //     _vaultName = _getVaultName();
  //   }
  //   return _vaultName;
  // }

  TaskManager(this.storage,
      {this.dateTemplate = "yyyy-MM-dd",
      this.todoOnly = false,
      this.forDateOnly})
      : _taskFilter = "";

  static bool sameDate(DateTime? date, DateTime? expectedDate) {
    // if expected date is not defined then any dates are OK
    if (expectedDate == null || (expectedDate == null && date == null)) {
      return true;
    }

    if (date == null) return false;

    final today =
        DateTime(expectedDate.year, expectedDate.month, expectedDate.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);
    if (dateToCheck == today) return true;

    return false;
  }

  // function returns true if date is before or equal to today
  static bool isPastDate(DateTime? date, DateTime inputToday) {
    if (date == null) return false;

    final DateTime today =
        DateTime(inputToday.year, inputToday.month, inputToday.day);
    final DateTime targetDate = DateTime(date.year, date.month, date.day);
    return targetDate.isBefore(today);
  }

  static TaskScheduleState getTaskScheduleState(Task task) {
    TaskScheduleState state = TaskScheduleState.none;
    if (task.due != null && TaskManager.sameDate(task.due, DateTime.now())) {
      state = TaskScheduleState.dueToday;
    } else {
      if (task.due != null &&
          TaskManager.isPastDate(task.due, DateTime.now())) {
        state = TaskScheduleState.overdue;
      }
    }

    if (task.scheduled != null &&
        TaskManager.isPastDate(task.scheduled, DateTime.now())) {
      state = TaskScheduleState.overdue;
    }

    return state;
  }

  Future loadTasks(String path,
      {String taskFilter = "", String taskNotePath = ""}) async {
    status = TaskManagerStatus.loading;
    Logger().i("loadTasks started");
    final startTime = DateTime.now();
    try {
      lastError = null;
      var removeCache = false;

      if (_path != path || _taskFilter != taskFilter) {
        _vaultName = "";
        _taskFilter = taskFilter;
        removeCache = true;
        _allTags = [];
      }

      _path = path;

      List<TasksFile> onlyFiles = await storage.getAllFiles(path);

      if (onlyFiles.isEmpty) {
        Logger().i("No changes in files.");
        return;
      }

      // Remove tasks from _tasks which contains file source with the filename returned in onlyFiles
      _tasks.removeWhere((task) =>
          onlyFiles.any((file) => task.taskSource!.fileName == file.path));

      // Process tasks (single-line switch: iOS = direct, others = isolate)
      final result =
          await (Platform.isIOS ? _processTasksDirect : _processTasksInIsolate)(
        onlyFiles,
        taskFilter,
        todoOnly,
        forDateOnly,
        taskNotePath,
      );

      if (result.error != null) {
        lastError = result.error;
        Logger().e("Error occurred during task processing in isolate.",
            error: result.error);
        Logger().e("Error occurred during task processing in isolate.",
            error: result.error);
      } else {
        // Update tags from isolate result
        final Set<String> allTagsSet = Set<String>.from(_allTags);
        allTagsSet.addAll(result.allTags);
        _allTags = allTagsSet.toList()..sort();

        if (removeCache) {
          _tasks = result.tasks;
        } else {
          _tasks.addAll(result.tasks);
        }
      }
    } catch (e) {
      lastError = e;
      Logger().e("Error occurred during loading tasks.", error: e);
    } finally {
      Logger().i("loadTasks finished");
      status = TaskManagerStatus.loaded;
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      Logger().i("loadTasks took ${duration.inMilliseconds} ms");
      notifyListeners();
    }
  }

  Future<TaskProcessingResult> _processTasksInIsolate(
    List<TasksFile> files,
    String taskFilter,
    bool todoOnly,
    DateTime? forDateOnly,
    String taskNotePath,
  ) async {
    // Ensure worker isolate is running
    final worker = await TaskWorker.ensureStarted();

    // Create a reply port for this request
    final replyPort = ReceivePort();
    final requestId = DateTime.now().microsecondsSinceEpoch;

    // Accumulate results from chunked responses
    final List<Task> tasks = [];
    final Set<String> allTags = <String>{};
    Object? error;

    // Listen for batches and completion
    late final StreamSubscription sub;
    final completer = Completer<void>();
    sub = replyPort.listen((message) {
      try {
        if (message is Map) {
          final int id = message['id'] as int;
          if (id != requestId) return; // ignore other requests
          final String type = message['type'] as String;
          if (type == 'batch') {
            final List<dynamic> batchTasks = message['tasks'] as List<dynamic>;
            final List<dynamic> batchTags = message['tags'] as List<dynamic>;
            // Tasks are already Task instances coming from isolate
            tasks.addAll(batchTasks.cast<Task>());
            allTags.addAll(batchTags.cast<String>());
          } else if (type == 'done') {
            completer.complete();
          } else if (type == 'error') {
            error = message['error'];
            completer.complete();
          }
        }
      } catch (e) {
        error = e;
        completer.complete();
      }
    });

    // Send request to worker
    worker.sendPort.send({
      'type': 'process',
      'id': requestId,
      'files': files,
      'taskFilter': taskFilter,
      'todoOnly': todoOnly,
      'forDateOnly': forDateOnly,
      'replyPort': replyPort.sendPort,
    });

    try {
      await completer.future; // wait for done/error
    } catch (_) {
      // no-op
    } finally {
      await sub.cancel();
      replyPort.close();
    }

    return TaskProcessingResult(
      tasks: tasks,
      allTags: allTags.toList()..sort(),
      error: error,
    );
  }

  // Direct processing on main isolate (used for iOS)
  Future<TaskProcessingResult> _processTasksDirect(
    List<TasksFile> files,
    String taskFilter,
    bool todoOnly,
    DateTime? forDateOnly,
    String taskNotePath,
  ) async {
    try {
      final List<Task> tasks = [];
      final Set<String> allTags = <String>{};
      for (int i = 0; i < files.length; i++) {
        final f = files[i];
        try {
          final iterTasks = await Parser.readTasks(
            f,
            fileNumber: i,
            taskFilter: taskFilter,
          );
          final filtered =
              filterAndCollect(iterTasks, todoOnly, forDateOnly, allTags);
          tasks.addAll(filtered);
        } catch (e) {
          Logger().e("Error in file ${f.path}", error: e);
        }
      }
      return TaskProcessingResult(
        tasks: tasks,
        allTags: allTags.toList()..sort(),
        error: null,
      );
    } catch (e) {
      return TaskProcessingResult(tasks: const [], allTags: const [], error: e);
    }
  }

  Future<List<Task>> getTodayTasks() async {
    return filterTasks(DateTime.now(), false);
  }

  Task? getTaskByFileAndOffset(String fileName, int fileOffset) {
    Task? task;
    try {
      task = _tasks.firstWhere(
        (task) =>
            task.taskSource?.fileName == fileName &&
            task.taskSource?.offset == fileOffset,
      );
    } catch (e) {
      Logger().e(
          "Task not found for fileName: $fileName, fileOffset: $fileOffset",
          error: e);
      return null;
    }
    return task;
  }

  Future setStatus(Task task, TaskStatus newStatus) async {
    task.status = newStatus;
    if (task.taskSource != null) {
      var newTask = _manageRecurrentTask(task);
      var tasks2Save = newTask != null ? [newTask, task] : [task];

      await saveTasks(tasks2Save);
    }
  }

  Future removeFromToday(Task task) async {
    task.scheduled = null;
    if (task.taskSource != null) {
      await saveTask(task);
    }
  }

  Future scheduleForToday(Task task) async {
    task.scheduled = DateTime.now();
    if (task.taskSource != null) {
      await saveTask(task);
    }
  }

  Future saveTask(Task task, {String? filePath, String? saveMarker}) async {
    return await saveTasks([task], filePath: filePath, saveMarker: saveMarker);
  }

  Future saveTasks(List<Task> tasks,
      {String? filePath, String? saveMarker}) async {
    var fileIndex = filePath == null ? tasks[0].taskSource!.fileNumber : 0;
    var content = await TaskSaver(storage).saveTasks(tasks,
        filePath: filePath,
        dateTemplate: dateTemplate,
        taskFilter: _taskFilter,
        saveMarker: saveMarker);

    if (content != null) {
      var fileName = filePath ?? tasks[0].taskSource!.fileName;

      var updatedTasks = Parser.parseTasks(fileName, content,
          fileNumber: fileIndex, taskFilter: _taskFilter);

      var indexOfFirstTaskFromFile =
          _tasks.indexWhere((val) => val.taskSource!.fileName == fileName);
      if (indexOfFirstTaskFromFile == -1) {
        indexOfFirstTaskFromFile = 0;
      } else {
        _tasks.removeWhere((val) => val.taskSource!.fileName == fileName);
      }

      _addFilteredTasks(_tasks, updatedTasks, todoOnly, forDateOnly,
          position: indexOfFirstTaskFromFile);
    }
    notifyListeners();
  }

  Task? _manageRecurrentTask(Task task) {
    if (task.status == TaskStatus.done &&
        task.recurrenceRule != null &&
        task.scheduled != null) {
      // check if task is recurrent
      // if yes then check if it should be repeated today
      // if yes then create new task with the same description and status
      // and set the scheduled date to the next date
      var nextScheduledDate = RecurrentTask.calculateNextOccurrence(
          task.scheduled!, task.recurrenceRule!);
      // clone this task and set the scheduled date to the next date
      var newTask = Task(task.description,
          status: TaskStatus.todo,
          priority: task.priority,
          created: DateTime.now(),
          scheduled: nextScheduledDate,
          scheduledTime: task.scheduledTime,
          recurranceRule: task.recurrenceRule,
          taskSource: task.taskSource);
      newTask.tags = task.tags;
      return newTask;
    }
    return null;
  }

  void _addFilteredTasks(List<Task> tasks, List<Task> inputTasks2Add,
      bool todoOnly, DateTime? forDate,
      {int position = -1}) {
    var tasks2Add = inputTasks2Add;
    // load only tasks with todo status or with one of the date for today
    if (todoOnly) {
      var filtered = tasks2Add.where((element) {
        return (element.description != null &&
            element.description != "" &&
            (element.status == TaskStatus.todo ||
                sameDate(element.created, forDate) ||
                sameDate(element.start, forDate) ||
                sameDate(element.done, forDate) ||
                sameDate(element.scheduled, forDate) ||
                sameDate(element.cancelled, forDate)));
      });
      tasks2Add = filtered.toList();
    }

    // Collect tags from tasks being added (optimization: collect during loading)
    final Set<String> newTags = <String>{};
    for (final task in tasks2Add) {
      newTags.addAll(task.tags);
    }

    // Add new tags to the existing set
    final Set<String> allTagsSet = Set<String>.from(_allTags);
    allTagsSet.addAll(newTags);
    _allTags = allTagsSet.toList()..sort();

    if (position == -1) {
      tasks.addAll(tasks2Add);
    } else {
      _tasks.insertAll(position, tasks2Add);
    }
  }

  Future<List<Task>> filterTasks(
      DateTime scheduled, bool excludeThisDate) async {
    return _tasks.where((task) {
      var res = sameDate(task.scheduled, scheduled) ||
          (includeDueTasksInToday && sameDate(task.due, scheduled));
      return excludeThisDate ? !res : res;
    }).toList();
  }
}
