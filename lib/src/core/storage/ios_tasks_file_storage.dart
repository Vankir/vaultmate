import 'package:flutter/services.dart';
import 'package:obsi/src/core/storage/storage_interfaces.dart';

class IosTasksFile implements TasksFile {
  static const MethodChannel _platform = MethodChannel('icloud_files');
  String filePath;

  IosTasksFile(this.filePath);

  @override
  Future<void> create() async {
    try {
      await _platform.invokeMethod('TaskFileCreate', {
        'filePath': path,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to create file: ${e.message}');
    }
  }

  @override
  Future<void> delete() async {
    try {
      await _platform.invokeMethod('TaskFileDelete', {
        'filePath': path,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to delete file: ${e.message}');
    }
  }

  @override
  Future<bool> exists() async {
    try {
      final bool exists = await _platform.invokeMethod('TaskFileExists', {
        'filePath': path,
      });
      return exists;
    } on PlatformException catch (e) {
      throw Exception('Failed to check if file exists: ${e.message}');
    }
  }

  @override
  String get path => filePath;

  @override
  String toString() {
    return path.toString();
  }

  @override
  Future<String> readAsString() async {
    try {
      // Use the native TaskFileReadAsString method
      final String content =
          await _platform.invokeMethod('TaskFileReadAsString', {
        'filePath': path,
      });
      return content;
    } on PlatformException catch (e) {
      throw Exception('Failed to read file: ${e.message}');
    }
  }

  @override
  Future<void> writeAsString(String content) async {
    try {
      await _platform.invokeMethod('TaskFileWriteAsString', {
        'filePath': path,
        'content': content,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to write file: ${e.message}');
    }
  }
}

class IosTasksFileStorage implements TasksFileStorage {
  static const MethodChannel _platform = MethodChannel('icloud_files');

  /// Static method to prompt the user to select a folder
  static Future<String?> selectFolder() async {
    try {
      final String? selectedPath = await _platform.invokeMethod('selectFolder');
      return selectedPath;
    } on PlatformException catch (e) {
      throw Exception('Failed to select folder: ${e.message}');
    }
  }

  @override
  String? todayFile;

  @override
  Future<List<TasksFile>> getAllFiles(String path) async {
    try {
      // Get all files using the native getAllFiles method
      final List<dynamic> files = await _platform.invokeMethod('getAllFiles');

      // Convert the file paths to TasksFile objects
      return files
          .cast<String>()
          .map((filePath) => IosTasksFile(filePath))
          .toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to get files: ${e.message}');
    }
  }

  @override
  TasksFile getFile(String path) {
    return IosTasksFile(path);
  }
}
