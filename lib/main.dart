import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/background/background_service_initializer.dart';
import 'package:obsi/src/core/notification_manager.dart';
import 'package:obsi/src/core/storage/storage_interfaces.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/core/subscription/subscription_manager.dart';
import 'package:obsi/src/core/intent_service.dart';

import 'app.dart';
import 'src/screens/settings/settings_controller.dart';
import 'src/screens/settings/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isIOS) {
    await HomeWidget.setAppGroupId('group.com.vankir.vaultmate');
  }
  final settingsController =
      SettingsController.getInstance(settingsService: SettingsService());
  var storage = TasksFileStorage.getInstance();
  final taskManager =
      TaskManager(storage, todoOnly: true, forDateOnly: DateTime.now());

  var notificationManager = NotificationManager.getInstance();
  await notificationManager.initialize();

  if (Platform.isAndroid) {
    await notificationManager.createBackgroundServiceChannel();
  }

  // Initialize subscription manager
  final subscriptionManager = SubscriptionManager.instance;
  await subscriptionManager.initialize();

  // Initialize intent service
  await IntentService.instance.initialize();

  if (!await notificationManager.notificationPermissionGranted()) {
    await notificationManager.requestExactAlarmPermission();
  }

  await settingsController.loadSettings();
  var storagePermissions = await SettingsController.storagePermissionsGranted();
  if (!storagePermissions) {
    Logger().i("Storage permission is not granted");
    await settingsController.updateVaultDirectory(null);
  }

  if (settingsController.vaultDirectory != null &&
      settingsController.vaultDirectory != '') {
    taskManager.loadTasks(settingsController.vaultDirectory!,
        taskFilter: settingsController.globalTaskFilter);

    if (Platform.isAndroid && settingsController.backgroundMonitoringEnabled) {
      final backgroundService = BackgroundServiceInitializer();
      await backgroundService.initialize();
      await backgroundService.startService(settingsController.vaultDirectory!);
    }
  }

  runApp(App(
    settingsController: settingsController,
    taskManager: taskManager,
  ));
}
