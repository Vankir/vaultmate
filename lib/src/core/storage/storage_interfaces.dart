import 'dart:io';

import 'package:obsi/src/core/storage/android_tasks_file_storage.dart';
import 'package:obsi/src/core/storage/changed_files_storage.dart';
import 'package:obsi/src/core/storage/ios_tasks_file_storage.dart';

abstract class TasksFile {
  String get path;
  Future<String> readAsString();
  Future<void> writeAsString(String content);
  Future<bool> exists();
  Future<void> create();
  Future<void> delete();
}

abstract class TasksFileStorage {
  static TasksFileStorage? _instance;

  String? todayFile = "";

  factory TasksFileStorage.getInstance({bool resetCache = false}) {
    if (resetCache) {
      _instance = null;
    }
    if (_instance != null) return _instance!;

    if (Platform.isIOS) {
      _instance = ChangedFilesStorage(IosTasksFileStorage());
    } else {
      _instance = ChangedFilesStorage(AndroidTasksFileStorage());
    }

    return _instance!;
  }

  Future<List<TasksFile>> getAllFiles(String path);
  TasksFile getFile(String path);
}
