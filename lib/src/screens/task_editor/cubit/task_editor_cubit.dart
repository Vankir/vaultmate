import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/notification_manager.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/core/tasks/task_source.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
part 'task_editor_state.dart';

class TaskEditorCubit extends Cubit<TaskEditorState> {
  final TaskManager _taskManager;
  final String? _createTasksPath;
  final Task _currentTask;
  String? _currentDescription;
  bool _chooseFileEnabled = false;
  bool _taskNoteFormat = false;

  TaskEditorCubit(this._taskManager, {Task? task, String? createTasksPath})
      : _createTasksPath = createTasksPath,
        _currentTask = task ?? Task(""),
        _currentDescription = task?.description,
        super(TaskEditorInitial(task)) {
    _chooseFileEnabled = SettingsController.getInstance().chooseFileEnabled;
  }

  bool get chooseFileEnabled => _chooseFileEnabled;
  bool get taskNoteFormat => _taskNoteFormat;
  bool get isNewTask => _currentTask.taskSource == null;

  void toggleChooseFile(bool value) {
    _chooseFileEnabled = value;
    SettingsController.getInstance().updateChooseFileEnabled(value);
    emit(TaskEditorInitial(_currentTask));
  }

  void toggleTaskNoteFormat(bool value) {
    _taskNoteFormat = value;
    emit(TaskEditorInitial(_currentTask));
  }

  Future<void> saveTask(BuildContext context) async {
    try {
      _currentTask.description = _currentDescription;

      String? filePath = _createTasksPath;
      String? saveMarker;

      if (isNewTask && _taskNoteFormat) {
        filePath = await _handleTaskNoteFormat(context);
        if (filePath == null) {
          return;
        }
      } else if (isNewTask && _chooseFileEnabled) {
        final result = await _handleChooseFile(context);
        if (result == null) {
          return;
        }
        filePath = result.$1;
        saveMarker = result.$2;
      } else if (_createTasksPath != null) {
        saveMarker = SettingsController.getInstance().saveMarker;
      }

      await _taskManager.saveTask(
        _currentTask,
        filePath: filePath,
        saveMarker: saveMarker,
      );

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      Logger().e('Error saving task: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving task: $e')),
        );
      }
    }
  }

  void setPriority(TaskPriority priority) {
    _currentTask.priority = priority;
    emit(TaskEditorInitial(_currentTask));
  }

  /// Gets all available tags from TaskManager
  List<String> getAllTags() {
    return _taskManager.allTags;
  }

  /// Gets tags for the current task
  List<String> getCurrentTaskTags() {
    return _currentTask.tags;
  }

  /// Toggles a tag for the current task
  void toggleTag(String tag) {
    final currentTags = List<String>.from(_currentTask.tags);

    if (currentTags.contains(tag)) {
      // Remove tag from the list
      currentTags.remove(tag);
    } else {
      // Add tag to the list
      currentTags.add(tag);
    }

    _currentTask.tags = currentTags;
    emit(TaskEditorInitial(_currentTask));
  }

  void setDescription(String cleanDescription) {
    _currentDescription = cleanDescription;
    emit(TaskEditorInitial(_currentTask));
  }

  void setStatus(TaskStatus status) {
    _currentTask.status = status;
    emit(TaskEditorInitial(_currentTask));
  }

  void setScheduledDate(DateTime? date) {
    if (date == null) {
      _currentTask.scheduled = null;
      emit(TaskEditorInitial(_currentTask));
      return;
    }

    final currentScheduled = _currentTask.scheduled;
    if (currentScheduled != null && _currentTask.scheduledTime) {
      _currentTask.scheduled = DateTime(
        date.year,
        date.month,
        date.day,
        currentScheduled.hour,
        currentScheduled.minute,
        currentScheduled.second,
        currentScheduled.millisecond,
        currentScheduled.microsecond,
      );
    } else {
      _currentTask.scheduled = date;
    }
    emit(TaskEditorInitial(_currentTask));
  }

  void setScheduledNotificationDateTime(DateTime? date) {
    if (date != null) {
      var notificationManager = NotificationManager.getInstance();

      notificationManager.requestExactAlarmPermission();

      _currentTask.scheduled = date;
      _currentTask.scheduledTime = true;
    } else {
      // null date in this method means - no scheduled time
      _currentTask.scheduledTime = false;
    }
    emit(TaskEditorInitial(_currentTask));
  }

  void setDueDate(DateTime? date) {
    _currentTask.due = date;
    emit(TaskEditorInitial(_currentTask));
  }

  void setRecurrenceRule(String? rule) {
    _currentTask.recurrenceRule = rule;
    emit(TaskEditorInitial(_currentTask));
  }

  void setStartDate(DateTime? date) {
    _currentTask.start = date;
    emit(TaskEditorInitial(_currentTask));
  }

  void setCancelledDate(DateTime? date) {
    _currentTask.cancelled = date;
    emit(TaskEditorInitial(_currentTask));
  }

  void setDoneDate(DateTime? date) {
    _currentTask.done = date;
    emit(TaskEditorInitial(_currentTask));
  }

  void setCreatedDate(DateTime? date) {
    _currentTask.created = date;
    emit(TaskEditorInitial(_currentTask));
  }

  Future<(String?, String?)?> _handleChooseFile(BuildContext context) async {
    final vaultDirectory = SettingsController.getInstance().vaultDirectory;
    if (vaultDirectory == null) {
      throw Exception('Please configure vault directory in settings');
    }

    final filePathPattern = SettingsController.getInstance().filePathPattern;
    final saveMarker = SettingsController.getInstance().saveMarker;

    if (filePathPattern != null && filePathPattern.isNotEmpty) {
      // Use pattern with date formatting instead of file picker
      final filePath = _formatFilePathPattern(filePathPattern, vaultDirectory);
      return (filePath, saveMarker);
    }

    // Show file picker dialog
    final lastSelectedFile = SettingsController.getInstance().lastSelectedFile;
    String? startDirectory = vaultDirectory;

    // If there was a previously selected file, use its directory
    if (lastSelectedFile != null && lastSelectedFile.isNotEmpty) {
      final lastSlashIndex = lastSelectedFile.lastIndexOf('/');
      if (lastSlashIndex > 0) {
        startDirectory = lastSelectedFile.substring(0, lastSlashIndex);
      }
    }

    final selectedPath = await SettingsController.selectFile(
      context,
      startDirectory: startDirectory,
    );

    if (selectedPath == null) {
      return null;
    }

    // Save the selected file path for next time
    await SettingsController.getInstance().updateLastSelectedFile(selectedPath);

    return (selectedPath, saveMarker);
  }

  Future<String?> _handleTaskNoteFormat(BuildContext context) async {
    final selectedFolder =
        await SettingsController.selectVaultDirectory(context);

    if (selectedFolder == null) {
      return null;
    }

    // Generate filename from description (max 15 characters)
    if (_currentDescription == null || _currentDescription!.trim().isEmpty) {
      throw Exception('Task description cannot be empty for TaskNote format');
    }

    String filename = _currentDescription!.trim();
    // Take first 15 characters and sanitize
    if (filename.length > 15) {
      filename = filename.substring(0, 15);
    }
    // Remove invalid filename characters
    filename = filename.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');

    final filePath = p.join(selectedFolder, '${filename}.md');

    // Set task source type to TaskNote
    _currentTask.taskSource = TaskSource(
      0, // fileNumber
      filePath, // fileName
      0, // offset
      0, // length
      type: TaskType.taskNote, // type
    );

    return filePath;
  }

  String _formatFilePathPattern(String pattern, String vaultDirectory) {
    final now = DateTime.now();
    final buffer = StringBuffer();
    int i = 0;

    while (i < pattern.length) {
      if (pattern[i] == '{') {
        // Find the closing bracket
        final closeIndex = pattern.indexOf('}', i);
        if (closeIndex == -1) {
          // No closing bracket, treat as literal
          buffer.write(pattern[i]);
          i++;
          continue;
        }

        // Extract content between brackets
        final content = pattern.substring(i + 1, closeIndex);

        if (content == 'vault') {
          // Replace with vault directory
          buffer.write(vaultDirectory);
        } else {
          // Treat as date format pattern
          try {
            buffer.write(DateFormat(content).format(now));
          } catch (e) {
            // If invalid format, keep original
            buffer.write('{$content}');
          }
        }

        i = closeIndex + 1;
      } else {
        // Regular character, copy as-is
        buffer.write(pattern[i]);
        i++;
      }
    }

    return buffer.toString();
  }

  Future<void> launchObsidian(BuildContext context) async {
    if (_currentTask.taskSource != null &&
        _currentTask.taskSource!.fileName != null) {
      var noteName = p.basenameWithoutExtension(
        _currentTask.taskSource!.fileName,
      );
      var vaultName = SettingsController.getInstance().vaultName;
      final query = 'obsidian://open?vault=$vaultName&file=$noteName';
      Logger().i('launchObsidian: $query');
      final Uri obsidianUri = Uri.parse(query);

      if (await canLaunchUrl(obsidianUri)) {
        await launchUrl(obsidianUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $obsidianUri')),
        );
      }
    }
  }
}
