import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:obsi/src/core/background/vault_monitor_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundServiceInitializer {
  static final BackgroundServiceInitializer _instance =
      BackgroundServiceInitializer._internal();

  factory BackgroundServiceInitializer() => _instance;

  BackgroundServiceInitializer._internal();

  final _logger = Logger();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      _logger.d('Background service already initialized');
      return;
    }

    if (!Platform.isAndroid) {
      _logger.i('Background service only supported on Android');
      return;
    }

    await _createNotificationChannel();

    final service = FlutterBackgroundService();

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'vault_monitor_service',
        initialNotificationTitle: 'VaultMate',
        initialNotificationContent: 'Monitoring vault for task changes',
        foregroundServiceNotificationId: 888,
      ),
    );

    _initialized = true;
    _logger.i('Background service initialized');
  }

  Future<void> _createNotificationChannel() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'vault_monitor_service',
      'Vault Monitor Service',
      description: 'Background service monitoring vault for task changes',
      importance: Importance.low,
      showBadge: false,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> startService(String vaultDirectory) async {
    if (!Platform.isAndroid) {
      _logger.w('Background service only supported on Android');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vaultDirectory', vaultDirectory);

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      _logger.d('Service already running, restarting...');
      await stopService();
      await Future.delayed(const Duration(seconds: 1));
    }

    await service.startService();
    _logger.i('Background service started for vault: $vaultDirectory');
  }

  Future<void> stopService() async {
    if (!Platform.isAndroid) {
      return;
    }

    final service = FlutterBackgroundService();
    service.invoke('stopService');
    _logger.i('Background service stop requested');
  }

  Future<bool> isServiceRunning() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  @pragma('vm:entry-point')
  static bool _onIosBackground(ServiceInstance service) {
    return true;
  }
}
