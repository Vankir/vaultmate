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
  bool _taskNoteFormat = false;
  // Set only once the user proactively picks a different file via the
  // "Change file" button; null means "use the default file" (_createTasksPath).
  String? _selectedFilePath;
  String? _selectedSaveMarker;
  // Set once a TaskNote folder is picked this session (proactively via
  // "Change folder", or as a fallback the first time there's no persisted
  // last-used folder yet); null means "use the persisted last-used folder".
  String? _selectedTaskNoteFolder;

  TaskEditorCubit(this._taskManager, {Task? task, String? createTasksPath})
      : _createTasksPath = createTasksPath,
        _currentTask = task ?? Task(""),
        _currentDescription = task?.description,
        super(TaskEditorInitial(task)) {
    // Pre-select the default task format for new tasks only; editing an
    // existing task must never be affected by this preference (FR-018).
    if (isNewTask) {
      switch (SettingsController.getInstance().taskFormatPreference) {
        case 'taskNote':
          _taskNoteFormat = true;
          break;
        case 'inline':
        case 'both':
        default:
          // "both" intentionally leaves nothing pre-selected, matching
          // today's default-off toggle (FR-014).
          _taskNoteFormat = false;
      }
    }
  }

  bool get taskNoteFormat => _taskNoteFormat;
  bool get isNewTask => _currentTask.taskSource == null;

  /// Whether the per-task "TaskNote format" choice should be shown at all.
  /// Only meaningful when the user's default task format preference is
  /// "both" — if they've picked a firm default (Inline or TaskNotes), every
  /// new task already uses it and there's nothing to choose per task.
  bool get showTaskFormatChoice =>
      isNewTask && SettingsController.getInstance().taskFormatPreference == 'both';

  /// The file a new (non-TaskNote) task will be saved to if the user
  /// doesn't change it — the just-picked file once "Change file" has been
  /// used, otherwise the app's configured default tasks file.
  String get targetFileDisplayName {
    final path = _selectedFilePath ?? _createTasksPath;
    if (path == null || path.isEmpty) {
      return SettingsController.getInstance().tasksFile;
    }
    return p.basename(path);
  }

  /// Lets the user proactively pick a different file to save this new task
  /// to, instead of the default tasks file — shown next to the file name
  /// at the bottom of the editor, so no picker prompt is needed at save
  /// time.
  Future<void> chooseTargetFile(BuildContext context) async {
    final result = await _handleChooseFile(context);
    if (result == null) {
      return;
    }
    _selectedFilePath = result.$1;
    _selectedSaveMarker = result.$2;
    emit(TaskEditorInitial(_currentTask));
  }

  /// The folder a new TaskNote task will be saved into if the user doesn't
  /// change it — the just-picked folder once "Change folder" has been used
  /// this session, otherwise the persisted last-used TaskNote folder (null
  /// if a TaskNote task has never been saved before).
  String? get targetTaskNoteFolder =>
      _selectedTaskNoteFolder ??
      SettingsController.getInstance().lastTaskNoteFolder;

  String get targetTaskNoteFolderDisplayName {
    final folder = targetTaskNoteFolder;
    return folder != null ? p.basename(folder) : 'Choose folder';
  }

  /// The file name (with extension) a new TaskNote task will be created
  /// as, generated live from the current description — empty until the
  /// user has typed something.
  String get targetTaskNoteFileName {
    final description = _currentDescription?.trim() ?? '';
    if (description.isEmpty) {
      return '';
    }
    return '${sanitizeTaskNoteFilename(description)}.md';
  }

  /// What to show on the Save button and the bottom file link for a new
  /// TaskNote task: the folder (or a placeholder if none chosen yet)
  /// combined with the live-generated file name (once there's a
  /// description to generate one from).
  String get targetTaskNoteDisplayPath {
    final folder = targetTaskNoteFolder;
    final fileName = targetTaskNoteFileName;
    if (folder == null) {
      return fileName.isEmpty ? 'Choose folder' : fileName;
    }
    final folderName = p.basename(folder);
    return fileName.isEmpty ? folderName : '$folderName/$fileName';
  }

  /// Lets the user proactively pick a different folder to save this
  /// TaskNote task into — shown next to the folder name, so no picker
  /// prompt is needed at save time if they're happy with the last-used
  /// (or default) folder.
  Future<void> chooseTaskNoteFolder(BuildContext context) async {
    final selected = await SettingsController.selectVaultDirectory(
      context,
      initialDirectory: targetTaskNoteFolder,
    );
    if (selected == null) {
      return;
    }
    _selectedTaskNoteFolder = selected;
    await SettingsController.getInstance().updateLastTaskNoteFolder(selected);
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
      } else if (isNewTask && _selectedFilePath != null) {
        filePath = _selectedFilePath;
        saveMarker = _selectedSaveMarker;
      } else if (_createTasksPath != null) {
        saveMarker = SettingsController.getInstance().saveMarker;
      }

      await _taskManager.saveTask(
        _currentTask,
        filePath: filePath,
        saveMarker: saveMarker,
        dataViewDefaultMarkdownFormat:
            SettingsController.getInstance().dataViewDefaultMarkdownFormat,
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

  /// Builds a safe, single-line file name (without extension) from a task
  /// description for TaskNote-format file creation. Whitespace runs
  /// (including line breaks from a multi-line description) are collapsed
  /// into single spaces before truncating, so a line break never ends up
  /// embedded in the resulting file name.
  static String sanitizeTaskNoteFilename(String description) {
    var filename = description.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (filename.length > 15) {
      filename = filename.substring(0, 15).trim();
    }
    return filename.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
  }

  Future<String?> _handleTaskNoteFormat(BuildContext context) async {
    // Use whatever folder is already known (picked via "Change folder" this
    // session, or the persisted last-used folder) without prompting. Only
    // fall back to the picker the very first time there's no folder to
    // fall back on yet.
    var selectedFolder = targetTaskNoteFolder;
    if (selectedFolder == null) {
      selectedFolder = await SettingsController.selectVaultDirectory(context);
      if (selectedFolder == null) {
        return null;
      }
      _selectedTaskNoteFolder = selectedFolder;
      await SettingsController.getInstance()
          .updateLastTaskNoteFolder(selectedFolder);
    }

    // Generate filename from description (max 15 characters)
    if (_currentDescription == null || _currentDescription!.trim().isEmpty) {
      throw Exception('Task description cannot be empty for TaskNote format');
    }

    final filename = sanitizeTaskNoteFilename(_currentDescription!);
    final filePath = p.join(selectedFolder, '$filename.md');

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
      await _launchObsidianForFile(context, _currentTask.taskSource!.fileName);
    }
  }

  /// Opens the target file a new (non-TaskNote) task would be saved to —
  /// same link behavior as [launchObsidian], but for a file that may not
  /// contain this task yet.
  Future<void> openTargetFileInObsidian(BuildContext context) async {
    final path = _selectedFilePath ?? _createTasksPath;
    if (path != null) {
      await _launchObsidianForFile(context, path);
    }
  }

  Future<void> _launchObsidianForFile(
      BuildContext context, String filePath) async {
    var noteName = p.basenameWithoutExtension(filePath);
    var vaultName = SettingsController.getInstance().vaultName;
    final query = 'obsidian://open?vault=$vaultName&file=$noteName';
    Logger().i('launchObsidian: $query');
    final Uri obsidianUri = Uri.parse(query);

    if (await canLaunchUrl(obsidianUri)) {
      await launchUrl(obsidianUri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $obsidianUri')),
      );
    }
  }
}
