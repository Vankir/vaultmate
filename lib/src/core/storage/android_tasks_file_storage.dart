import 'dart:io';

import 'package:obsi/src/core/storage/storage_interfaces.dart';
import 'package:path/path.dart' as p;

class AndroidTasksFile implements TasksFile {
  final File _file;
  AndroidTasksFile(File file) : _file = file;

  @override
  Future<void> create() async {
    await _file.create();
  }

  @override
  Future<void> delete() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }

  @override
  Future<bool> exists() async {
    return await _file.exists();
  }

  @override
  String get path => _file.path;

  @override
  Future<String> readAsString() async {
    return await _file.readAsString();
  }

  @override
  Future<File> writeAsString(String content) async {
    return await _file.writeAsString(content);
  }

  @override
  String toString() {
    return _file.path.toString();
  }
}

class AndroidTasksFileStorage implements TasksFileStorage {
  final Map<String, bool> _hiddenFoldersCache = {};

  @override
  Future<List<TasksFile>> getAllFiles(String path) async {
    final List<TasksFile> onlyFiles = [];
    final dir = Directory(path);
    // Use async directory listing to avoid blocking the UI thread on large folders
    await for (final entity
        in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && !_isHidden(entity.path) && p.extension(entity.path) == ".md") {
        onlyFiles.add(AndroidTasksFile(entity));
      }
    }
    return onlyFiles;
  }

  @override
  TasksFile getFile(String path) {
    return AndroidTasksFile(File(path));
  }

  bool _isHidden(String path) {
    if (_hiddenFoldersCache.containsKey(path)) {
      return _hiddenFoldersCache[path]!;
    }

    final List<String> parts = p.split(path);
    for (String part in parts) {
      if (part.startsWith('.')) {
        _hiddenFoldersCache[path] = true;
        return true;
      }
    }
    _hiddenFoldersCache[path] = false;
    return false;
  }

  @override
  String? todayFile;
}
