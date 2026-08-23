import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/notification_manager.dart';
import 'package:obsi/src/core/storage/storage_interfaces.dart';
import 'package:obsi/src/core/system_widget.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/settings/settings_service.dart';
import 'package:path/path.dart' as p;
part 'inbox_tasks_state.dart';

class InboxTasksCubit extends Cubit<InboxTasksState> {
  final bool today;
  final TaskManager _taskManager;
  List<Task> _tasks = [];
  TaskManager get taskManager => _taskManager;
  String searchQuery = "";
  final Set<String> _selectedTags = <String>{};
  final Set<String> _excludedTags = <String>{};
  int _taskDoneCount = 0;
  int _taskCount = 0;

  // Transient, in-memory only (FR-016): never routed through
  // SettingsController, deliberately cleared only in refreshTasks() - not in
  // tasksChangedListener(), which also fires on every ordinary task edit and
  // would otherwise reset a user's collapsed groups constantly. See
  // research.md Decision 9.
  final Set<int> _collapsedTaskIds = <int>{};

  SortMode get sortMode => SettingsController.getInstance().sortMode;
  ViewMode get viewMode => SettingsController.getInstance().viewMode;
  bool get showOverdueOnly => SettingsController.getInstance().showOverdueOnly;
  bool get swipeHintShown => today
      ? SettingsController.getInstance().swipeHintShownToday
      : SettingsController.getInstance().swipeHintShownInbox;
  Set<String> get selectedTags => Set.from(_selectedTags);
  Set<String> get excludedTags => Set.from(_excludedTags);
  List<String> get availableTags => _taskManager.allTags;
  String get caption {
    return today ? "Today" : "Inbox";
  }

  String get subcaption {
    var todayDate = DateFormat(SettingsController.getInstance().dateTemplate)
        .format(DateTime.now());
    return today
        ? "$todayDate\nTasks: $_taskDoneCount/$_taskCount"
        : "Tasks: $_taskDoneCount/$_taskCount";
  }

  InboxTasksCubit(TaskManager taskManager, this.today)
      : _taskManager = taskManager,
        super(InboxTasksLoading(
            SettingsController.getInstance().vaultDirectory!)) {
    SettingsController.getInstance().addListener(() {
      refreshTasks();
    });
    if (_taskManager.status == TaskManagerStatus.loaded) {
      tasksChangedListener();
    }

    _taskManager.addListener(tasksChangedListener);
  }

  void updateSearchQuery(String query) {
    searchQuery = query;
    _applySearchFilter();
  }

  void toggleTag(String tag) {
    // If tag is excluded, remove it from excluded first
    if (_excludedTags.contains(tag)) {
      _excludedTags.remove(tag);
    }
    
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    _applySearchFilter();
  }

  void toggleExcludeTag(String tag) {
    // If tag is selected, remove it from selected first
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    }
    
    if (_excludedTags.contains(tag)) {
      _excludedTags.remove(tag);
    } else {
      _excludedTags.add(tag);
    }
    _applySearchFilter();
  }

  void clearTagFilter() {
    _selectedTags.clear();
    _excludedTags.clear();
    _applySearchFilter();
  }

  void _updateView(List<Task> tasks) {
    if (taskManager.lastError != null) {
      emit(InboxTasksMessage(taskManager.lastError.toString(), []));
      taskManager.lastError = null;
    } else {
      emit(InboxTasksList(tasks));
    }
  }

  void _applySearchFilter() {
    // Filter is applied either to description or file name
    int taskDoneCount = 0;
    if (_tasks.isEmpty) {
      // If tasks are not loaded yet, keep current state (e.g., loading spinner)
      if (taskManager.status != TaskManagerStatus.loaded) {
        return;
      }
      // If tasks finished loading but none matched, emit empty list
      Logger().d("_applySearchFilter: _tasks is empty");

      _updateView([]);
      return;
    }

    var filteredTasks = _tasks.where((task) {
      if (task.status == TaskStatus.done) {
        taskDoneCount++;
      }

      var description = task.description ?? "";
      var fileName = task.taskSource?.fileName ?? "";
      fileName = p.basenameWithoutExtension(fileName);
      bool matchesQuery =
          description.toLowerCase().contains(searchQuery.toLowerCase()) ||
              (viewMode == ViewMode.grouped &&
                  fileName.toLowerCase().contains(searchQuery.toLowerCase()));

      // Apply tag filtering
      bool matchesTags = true;
      if (_selectedTags.isNotEmpty) {
        // Task must have at least one of the selected tags
        matchesTags =
            _selectedTags.any((selectedTag) => task.tags.contains(selectedTag));
      }
      
      // Apply tag exclusion filtering
      bool notExcluded = true;
      if (_excludedTags.isNotEmpty) {
        // Task must not have any of the excluded tags
        notExcluded =
            !_excludedTags.any((excludedTag) => task.tags.contains(excludedTag));
      }

      if (showOverdueOnly) {
        var taskState =
            TaskManager.getTaskScheduleState(task) != TaskScheduleState.none;
        matchesQuery = matchesQuery && taskState;
      }

      return matchesQuery && matchesTags && notExcluded;
    }).toList();

    _taskDoneCount = taskDoneCount;
    _taskCount = filteredTasks.length;
    _updateView(filteredTasks);
  }

  void tasksChangedListener() {
    Logger().i("Tasks changed listener called");
    //register notifications only once, only for today view
    if (today) {
      _scheduleNotifications(_taskManager.tasks);
      //TODO update widget only for android because ios is not supported yet
      if (Platform.isAndroid) {
        _taskManager.getTodayTasks().then((tasks) {
          HomeWidgetHandler.updateWidget(tasks);
        });
      }
    }

    _taskManager.filterTasks(DateTime.now(), !today).then((filteredTasks) {
      _tasks = filteredTasks;

      _applySearchFilter();
    });
  }

  Future changeTaskStatus(Task task, TaskStatus status) async {
    if (status == TaskStatus.done) {
      task.done = DateTime.now();
    } else {
      task.done = null;
    }

    _taskManager.setStatus(task, status);
    // TODO need to optimize because this method go through ALL tasks and rescheduled notifications instead of remove only one notification for this task
    _scheduleNotifications(_tasks);
  }

  Future<void> updateShowOverdueTasksOnly(bool showOverdueOnly) async {
    await SettingsController.getInstance()
        .updateShowOverdueOnly(showOverdueOnly);
    _applySearchFilter();
  }

  Future<void> updateViewMode(ViewMode inputViewMode) async {
    await SettingsController.getInstance().updateViewMode(inputViewMode);
    _applySearchFilter();
  }

  Future<void> updateSortMode(SortMode inputSortMode) async {
    await SettingsController.getInstance().updateSortMode(inputSortMode);
    _applySearchFilter();
  }

  bool isCollapsed(Task task) {
    final id = task.taskSource?.id;
    return id != null && _collapsedTaskIds.contains(id);
  }

  void toggleCollapsed(Task task) {
    final id = task.taskSource?.id;
    if (id == null) return;
    if (!_collapsedTaskIds.add(id)) {
      _collapsedTaskIds.remove(id);
    }
    _applySearchFilter();
  }

  bool _hasChildren(Task task) {
    final id = task.taskSource?.id;
    return id != null && _tasks.any((t) => t.parentTaskId == id);
  }

  void collapseAllInFile(String fileName) {
    for (final task in _tasks) {
      final id = task.taskSource?.id;
      if (id != null &&
          task.taskSource?.fileName == fileName &&
          _hasChildren(task)) {
        _collapsedTaskIds.add(id);
      }
    }
    _applySearchFilter();
  }

  void expandAllInFile(String fileName) {
    final idsInFile = _tasks
        .where((t) => t.taskSource?.fileName == fileName)
        .map((t) => t.taskSource?.id)
        .whereType<int>()
        .toSet();
    _collapsedTaskIds.removeAll(idsInFile);
    _applySearchFilter();
  }

  bool hasCollapsibleTasks(String fileName) {
    return _tasks.any(
        (t) => t.taskSource?.fileName == fileName && _hasChildren(t));
  }

  /// True only when every collapsible task in this file is currently
  /// collapsed - drives which icon/label the single collapse-all/expand-all
  /// toggle shows. False (never true) when the file has no collapsible
  /// tasks at all - callers should gate on hasCollapsibleTasks first.
  bool allCollapsedInFile(String fileName) {
    final collapsible = _tasks.where(
        (t) => t.taskSource?.fileName == fileName && _hasChildren(t));
    return collapsible.isNotEmpty && collapsible.every(isCollapsed);
  }

  void toggleCollapseAllInFile(String fileName) {
    if (allCollapsedInFile(fileName)) {
      expandAllInFile(fileName);
    } else {
      collapseAllInFile(fileName);
    }
  }

  void clearCollapsedTasks() {
    _collapsedTaskIds.clear();
  }

  void refreshTasks() {
    clearCollapsedTasks();
    var settings = SettingsController.getInstance();
    taskManager.dateTemplate = settings.dateTemplate;
    taskManager.includeDueTasksInToday = settings.includeDueTasksInToday;
    taskManager.storage = TasksFileStorage.getInstance();
    var vaultDirectory = settings.vaultDirectory;

    if (vaultDirectory != null) {
      emit(InboxTasksLoading(vaultDirectory));
      //Future.delayed(const Duration(seconds: 4)).then((value) {
      _taskManager.loadTasks(vaultDirectory,
          taskFilter: settings.globalTaskFilter);
      //});
    }
  }

  // Only removable from today if it's not due today (when includeDueTasksInToday is enabled)
  bool isBlockedFromLeavingToday(Task task) {
    return _taskManager.includeDueTasksInToday &&
        TaskManager.sameDate(task.due, DateTime.now());
  }

  void removeFromTodayPressed(Task task) {
    if (isBlockedFromLeavingToday(task)) {
      // Don't remove tasks that are due today when includeDueTasksInToday is enabled
      Logger().d('Task not removed from today because it is due today');
      emit(InboxTasksMessage(
        'Task cannot be removed from today because it is due today',
        _tasks,
      ));
      return;
    }
    _taskManager.removeFromToday(task);
  }

  void assignForTodayPressed(Task task) {
    _taskManager.scheduleForToday(task);
  }

  void postponeToTomorrowPressed(Task task) {
    _taskManager.scheduleForTomorrow(task);
  }

  Future<void> deleteTaskPressed(Task task) async {
    await _taskManager.deleteTask(task);
  }

  Future<void> markSwipeHintShown() async {
    if (swipeHintShown) return;
    if (today) {
      await SettingsController.getInstance().updateSwipeHintShownToday(true);
    } else {
      await SettingsController.getInstance().updateSwipeHintShownInbox(true);
    }
  }

  Future<void> _scheduleNotifications(List<Task> tasks) async {
    var notificationManager = NotificationManager.getInstance();
    var permissionGranted =
        await notificationManager.notificationPermissionGranted();

    if (!permissionGranted) {
      return;
    }

    await notificationManager.cancelAllNotifications();
    for (var task in tasks) {
      if (task.scheduledTime &&
          task.scheduled != null &&
          task.description != null &&
          task.status != TaskStatus.done &&
          task.scheduled!.isAfter(DateTime.now())) {
        var notificationId = task.taskSource?.id ?? 0;
        await notificationManager.createScheduledNotification(
            scheduledDate: task.scheduled!,
            text: task.description!,
            notificationId: notificationId);
      }
    }

    //TODO this is a shirt workaround because deaily reminders were cancelled by previous operation
    //need to think about better way to handle this
    var reviewTasksReminderTime =
        SettingsController.getInstance().reviewTasksReminderTime;
    var reviewCompletedReminderTime =
        SettingsController.getInstance().reviewCompletedReminderTime;

    if (reviewTasksReminderTime != null) {
      await SettingsController.getInstance()
          .updateReviewTasksReminderTime(reviewTasksReminderTime);
    }
    if (reviewCompletedReminderTime != null) {
      await SettingsController.getInstance()
          .updateReviewCompletedReminderTime(reviewCompletedReminderTime);
    }
  }
}
