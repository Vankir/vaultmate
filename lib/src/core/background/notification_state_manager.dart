import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class NotificationStateManager {
  static const String _notificationStateKey = 'scheduled_notifications';
  
  static NotificationStateManager? _instance;
  late SharedPreferences _prefs;
  
  NotificationStateManager._();
  
  static Future<NotificationStateManager> getInstance() async {
    if (_instance == null) {
      _instance = NotificationStateManager._();
      await _instance!._init();
    }
    return _instance!;
  }
  
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  String _generateTaskHash(String filePath, String description, DateTime? scheduled) {
    final content = '$filePath|$description|${scheduled?.toIso8601String() ?? ''}';
    return md5.convert(utf8.encode(content)).toString();
  }
  
  Future<bool> isNotificationScheduled(String filePath, String description, DateTime? scheduled) async {
    final hash = _generateTaskHash(filePath, description, scheduled);
    final scheduledNotifications = await getScheduledNotifications();
    return scheduledNotifications.contains(hash);
  }
  
  Future<void> markNotificationScheduled(String filePath, String description, DateTime? scheduled) async {
    final hash = _generateTaskHash(filePath, description, scheduled);
    final scheduledNotifications = await getScheduledNotifications();
    scheduledNotifications.add(hash);
    await _prefs.setStringList(_notificationStateKey, scheduledNotifications.toList());
  }
  
  Future<void> removeNotification(String filePath, String description, DateTime? scheduled) async {
    final hash = _generateTaskHash(filePath, description, scheduled);
    final scheduledNotifications = await getScheduledNotifications();
    scheduledNotifications.remove(hash);
    await _prefs.setStringList(_notificationStateKey, scheduledNotifications.toList());
  }
  
  Future<Set<String>> getScheduledNotifications() async {
    final list = _prefs.getStringList(_notificationStateKey) ?? [];
    return Set<String>.from(list);
  }
  
  Future<void> clearAll() async {
    await _prefs.remove(_notificationStateKey);
  }
}
