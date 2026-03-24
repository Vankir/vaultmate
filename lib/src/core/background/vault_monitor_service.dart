import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/background/notification_state_manager.dart';
import 'package:obsi/src/core/notification_manager.dart';
import 'package:obsi/src/core/storage/android_tasks_file_storage.dart';
import 'package:obsi/src/core/storage/changed_files_storage.dart';
import 'package:obsi/src/core/system_widget.dart';
import 'package:obsi/src/core/tasks/parsers/parser.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as path;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = Logger();
  logger.i('VaultMate background service started');

  final prefs = await SharedPreferences.getInstance();
  final vaultDirectory = prefs.getString('vaultDirectory');

  if (vaultDirectory == null || vaultDirectory.isEmpty) {
    logger.w('No vault directory configured, stopping service');
    service.stopSelf();
    return;
  }

  final notificationStateManager = await NotificationStateManager.getInstance();
  final notificationManager = NotificationManager.getInstance();
  await notificationManager.initialize();

  final vaultDir = Directory(vaultDirectory);
  if (!await vaultDir.exists()) {
    logger.w('Vault directory does not exist: $vaultDirectory');
    service.stopSelf();
    return;
  }

  // Load settings once and reuse
  final settings = SettingsController.getInstance(
    settingsService: SettingsService(),
  );
  await settings.loadSettings();

  // Debounce widget updates to avoid excessive refreshes
  Timer? widgetUpdateTimer;
  void scheduleWidgetUpdate() {
    widgetUpdateTimer?.cancel();
    widgetUpdateTimer = Timer(const Duration(seconds: 2), () async {
      await _updateHomeWidget(vaultDirectory, settings, logger);
    });
  }

  final watcher = DirectoryWatcher(vaultDirectory);

  service.on('stopService').listen((event) {
    logger.i('Stop service event received');
    service.stopSelf();
  });

  Future<void> processMarkdownFile(String filePath,
      {bool isDeleted = false}) async {
    try {
      if (!filePath.endsWith('.md')) {
        return;
      }

      bool shouldUpdateWidget = false;

      if (isDeleted) {
        // File was deleted, update widget to remove tasks from it
        logger.d('File deleted: $filePath');
        shouldUpdateWidget = true;
      } else {
        final file = File(filePath);
        if (!await file.exists()) {
          return;
        }

        logger.d('Processing file: $filePath');
        final tasksFile = AndroidTasksFile(file);
        final tasks = await Parser.readTasks(tasksFile);

        for (final task in tasks) {
          await _scheduleNotificationForTask(
            task,
            filePath,
            notificationStateManager,
            notificationManager,
            logger,
          );

          // Check if any tasks are scheduled for today
          if (task.scheduled != null && _isToday(task.scheduled!)) {
            shouldUpdateWidget = true;
          }
        }
      }

      // Debounce widget updates to avoid excessive refreshes
      if (shouldUpdateWidget) {
        scheduleWidgetUpdate();
      }
    } catch (e, stackTrace) {
      logger.e('Error processing file $filePath',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> scanAllMarkdownFiles() async {
    try {
      logger.i('Scanning all markdown files in vault');
      await for (final entity in vaultDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.md')) {
          await processMarkdownFile(entity.path);
        }
      }
    } catch (e, stackTrace) {
      logger.e('Error scanning vault', error: e, stackTrace: stackTrace);
    }
  }

  await scanAllMarkdownFiles();

  watcher.events.listen((event) async {
    logger.d('File event: ${event.type} - ${event.path}');

    if (event.type == ChangeType.MODIFY || event.type == ChangeType.ADD) {
      await processMarkdownFile(event.path);
    } else if (event.type == ChangeType.REMOVE) {
      // Handle file deletion - update widget if it had today's tasks
      await processMarkdownFile(event.path, isDeleted: true);
    }
  }, onError: (error, stackTrace) {
    logger.e('Watcher error', error: error, stackTrace: stackTrace);
  });

  Timer.periodic(const Duration(minutes: 30), (timer) async {
    logger.d('Periodic scan triggered');
    await scanAllMarkdownFiles();
  });

  service.invoke('serviceRunning');
}

Future<void> _scheduleNotificationForTask(
  Task task,
  String filePath,
  NotificationStateManager stateManager,
  NotificationManager notificationManager,
  Logger logger,
) async {
  // Only schedule if task has a scheduled date
  if (task.scheduled == null) {
    return;
  }

  // Only schedule if scheduledTime flag is true (has time component)
  if (!task.scheduledTime) {
    logger.d(
        'Task has scheduled date but no time, skipping: ${task.description}');
    return;
  }

  final scheduledTime = task.scheduled!;
  final now = DateTime.now();

  // Skip past dates
  if (scheduledTime.isBefore(now)) {
    logger.d('Scheduled time is in the past, skipping: ${task.description}');
    return;
  }

  final description = task.description ?? 'Task';

  // Check if already scheduled to prevent duplicates
  final alreadyScheduled = await stateManager.isNotificationScheduled(
    filePath,
    description,
    scheduledTime,
  );

  if (alreadyScheduled) {
    logger.d('Notification already scheduled for task: $description');
    return;
  }

  final fileName = path.basename(filePath);
  final notificationId =
      _generateNotificationId(filePath, description, scheduledTime);
  final notificationText = '$fileName: $description';

  try {
    // Use existing NotificationManager for consistency
    await notificationManager.createScheduledNotification(
      scheduledDate: scheduledTime,
      text: notificationText,
      notificationId: notificationId,
    );

    await stateManager.markNotificationScheduled(
        filePath, description, scheduledTime);
    logger.i('✓ Scheduled notification for: $description at $scheduledTime');
  } catch (e, stackTrace) {
    logger.e('Failed to schedule notification for: $description',
        error: e, stackTrace: stackTrace);
  }
}

int _generateNotificationId(
    String filePath, String description, DateTime scheduled) {
  final combined = '$filePath|$description|${scheduled.toIso8601String()}';
  // Ensure ID fits in 32-bit signed integer range
  return combined.hashCode.abs() % 2147483647;
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

Future<void> _updateHomeWidget(
  String vaultDirectory,
  SettingsController settings,
  Logger logger,
) async {
  try {
    logger.d('Updating home widget with today\'s tasks');

    final taskManager = TaskManager(
      ChangedFilesStorage(AndroidTasksFileStorage()),
      todoOnly: false,
    );

    taskManager.dateTemplate = settings.dateTemplate;

    await taskManager.loadTasks(
      vaultDirectory,
      taskFilter: settings.globalTaskFilter,
    );

    final todayTasks = await taskManager.getTodayTasks();
    await HomeWidgetHandler.updateWidget(todayTasks);

    logger.i('✓ Home widget updated with ${todayTasks.length} tasks');
  } catch (e, stackTrace) {
    logger.e('Error updating home widget', error: e, stackTrace: stackTrace);
  }
}
