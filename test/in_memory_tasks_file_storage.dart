import 'dart:async';

import 'package:obsi/src/core/storage/storage_interfaces.dart';

class InMemoryTasksFile implements TasksFile {
  final String _path;
  String _content;

  InMemoryTasksFile(this._path, [this._content = '']);

  @override
  Future<void> create() async {
    // Simulate file creation
  }

  @override
  Future<bool> exists() async {
    return true; // Always exists in memory
  }

  @override
  String get path => _path;

  @override
  Future<String> readAsString() async {
    return _content;
  }

  @override
  Future<void> writeAsString(String content) async {
    _content = content;
  }

  @override
  Future<void> delete() async {
    _content = '';
    _deleted = true;
  }

  bool _deleted = false;
  bool get isDeleted => _deleted;

  @override
  String toString() {
    return _path;
  }
}

class InMemoryTasksFileStorage implements TasksFileStorage {
  final Map<String, InMemoryTasksFile> _files = {};

  @override
  Future<List<TasksFile>> getAllFiles(String path) async {
    return _files.values
        .where(
            (file) => file.path.startsWith(path) && file.path.endsWith('.md'))
        .toList();
  }

  @override
  TasksFile getFile(String path) {
    return _files.putIfAbsent(path, () => InMemoryTasksFile(path));
  }

  @override
  String? todayFile;
}
