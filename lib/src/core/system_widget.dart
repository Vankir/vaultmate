import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/storage/android_tasks_file_storage.dart';
import 'package:obsi/src/core/storage/changed_files_storage.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/settings/settings_service.dart';

class HomeWidgetHandler {
  /// Widget-data key holding the global task filter (e.g. `#task`). The native
  /// widget code needs it to re-create a recurring task the same way the Dart
  /// side does — see Vankir/vaultmate#63.
  static const String globalTaskFilterKey = 'globalTaskFilter';

  @pragma("vm:entry-point")
  static Future<void> homeWidgetHandler(Uri? uri) async {
    try {
      Logger().i("Widget data update is called with uri: $uri");

      if (uri != null) {
        if (uri.host.contains('request_tasks')) {
          await _requestTasksHandler();
        } else {
          throw Exception("ObsiWidget: unknown request received");
        }
      }
    } catch (e) {
      Logger().e(e);
      _saveAndUpdateWidget("error", e.toString());
    }
  }

  static Future<void> updateWidget(List<Task> tasks) async {
    try {
      Logger().i("Updating widget with tasks: ${tasks.length}");
      await _saveGlobalTaskFilter();
      var jsonTasks = jsonEncode(_tasks2Json(tasks));
      await _saveAndUpdateWidget("tasks", jsonTasks);
    } catch (e) {
      Logger().e("Error updating widget: $e");
      await _saveAndUpdateWidget("error", e.toString());
    }
  }

  static Future _requestTasksHandler() async {
    Logger().i("HomeWidget: requesttasks received");
    await _saveGlobalTaskFilter();
    var tasks = await _getTodayTasks();
    var jsonTasks = jsonEncode(tasks);
    _saveAndUpdateWidget("tasks", jsonTasks.toString());
  }

  static Future _saveAndUpdateWidget(String key, String value) async {
    await HomeWidget.saveWidgetData<String>(key, value);
    await HomeWidget.updateWidget(
        name: 'ObsiWidgetReceiver', iOSName: 'HomeWidget');
  }

  /// Shares the global task filter with the widget state so the native widget
  /// code can append it when it re-creates the next occurrence of a recurring
  /// task — otherwise the new task is filtered out everywhere (see #63).
  static Future _saveGlobalTaskFilter() async {
    try {
      var settings =
          SettingsController.getInstance(settingsService: SettingsService());
      await settings.loadSettings();
      var taskFilter = settings.globalTaskFilter;
      await HomeWidget.saveWidgetData<String>(globalTaskFilterKey, taskFilter);
      Logger().d("HomeWidget: saved global task filter '$taskFilter'");
    } catch (e) {
      Logger().e("Error saving global task filter to widget state: $e");
    }
  }

  static Future<List<Map<String, dynamic>>?> _getTodayTasks() async {
    List<Map<String, dynamic>> resultTask = [];
    var settings =
        SettingsController.getInstance(settingsService: SettingsService());
    await settings.loadSettings();

    TaskManager taskManager = TaskManager(
      ChangedFilesStorage(AndroidTasksFileStorage()),
      todoOnly: false,
    );

    taskManager.dateTemplate = settings.dateTemplate;

    var vaultDirectory = settings.vaultDirectory;
    if (vaultDirectory != null && vaultDirectory.isNotEmpty) {
      Logger().d('Vault directory is set: $vaultDirectory');
      // Load tasks from the specified vault directory
      await taskManager.loadTasks(vaultDirectory,
          taskFilter: settings.globalTaskFilter);
      //return only tasks for today
      var tasks = await taskManager.getTodayTasks();
      resultTask = _tasks2Json(tasks);
    } else {
      Logger().d('Vault directory is not set or empty. Using default tasks.');
      throw Exception(
          "Vault directory is not set. Start application to set it.");
    }

    return resultTask;
  }

  static List<Map<String, dynamic>> _tasks2Json(List<Task> tasks) {
    return tasks.map((task) => task.toJsonMap()).toList();
  }
}
