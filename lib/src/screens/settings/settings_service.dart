import 'package:flutter/material.dart';
import 'package:obsi/src/screens/notes_widget_config/cubit/notes_widget_config_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ViewMode {
  grouped,
  list,
  calendar,
}

enum SortMode {
  none,
  byCreationDate,
}

class SettingsService {
  static const String _vaultDirectoryKey = "vault_directory";
  static const String _vaultNameKey = "vault_name";
  static const String _tasksFileKey = "tasks_file";
  static const String _dateTemplateKey = "date_template";
  //static const String _notificationTimeKey = "notif_time";
  static const String _viewModeKey = "view_mode";
  static const String _sortModeKey = "sort_mode";
  //static const String _notifTimeTemplate = "yyyy-MM-dd";
  static const String _globalTaskFilterKey = "global_task_filter";
  static const String _zeroDateKey = "zero_date";
  static const String _rateDialogCounterKey = "rate_dialog_counter";
  static const String _chatGptKeyKey = "chatgptkey";
  static const String _showOverdueOnlyKey = "show_overdue_only";
  static const String _includeDueTasksInTodayKey = "include_due_tasks_in_today";
  static const String _onboardingCompleteKey = "onboarding_complete";
  static const String _subscriptionStatusKey = "subscription_status";
  static const String _subscriptionExpiryKey = "subscription_expiry";
  static const String _reviewTasksReminderTimeKey =
      "review_tasks_reminder_time";
  static const String _reviewCompletedReminderTimeKey =
      "review_completed_reminder_time";
  static const String _saveMarkerKey = "save_marker";
  static const String _chooseFileEnabledKey = "choose_file_enabled";
  static const String _lastSelectedFileKey = "last_selected_file";
  static const String _filePathPatternKey = "file_path_pattern";
  static const String _showAITabKey = "show_ai_tab";
  static const String _dataViewDefaultMarkdownFormatKey =
      "data_view_default_markdown_format";

  Future<ThemeMode> themeMode() async => ThemeMode.system;

  Future<String?> chatGptKey() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_chatGptKeyKey);
  }

  Future<String?> vaultDirectory() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_vaultDirectoryKey);
  }

  Future<String?> vaultName() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_vaultNameKey);
  }

  Future<String?> tasksFile() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_tasksFileKey);
  }

  Future<String?> dateTemplate() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_dateTemplateKey);
  }

  Future<bool> dataViewDefaultMarkdownFormat() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    final storedFlag =
        sharedPreferences.getBool(_dataViewDefaultMarkdownFormatKey);
    if (storedFlag != null) {
      return storedFlag;
    }

    // Backward compatibility for old enum-based persistence.
    var legacyTaskFormatString = sharedPreferences.getString('task_format');
    if (legacyTaskFormatString != null) {
      return legacyTaskFormatString.endsWith('dataview');
    }

    return false;
  }

  // Future<DateTime?> notificationTime() async {
  //   var sharedPreferences = await SharedPreferences.getInstance();
  //   var dateTime = sharedPreferences.getString(_notificationTimeKey);
  //   if (dateTime != null) {
  //     return DateTime.parse(_notifTimeTemplate);
  //   }

  //   return null;
  // }

  Future<ViewMode> viewMode() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var viewModeString = sharedPreferences.getString(_viewModeKey);
    if (viewModeString != null) {
      return ViewMode.values.firstWhere(
        (e) => e.toString() == viewModeString,
        orElse: () => ViewMode.grouped, // Default value
      );
    }

    return ViewMode.grouped;
  }

  Future<SortMode> sortMode() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var sortModeString = sharedPreferences.getString(_sortModeKey);
    if (sortModeString != null) {
      return SortMode.values.firstWhere(
        (e) => e.toString() == sortModeString,
        orElse: () => SortMode.none, // Default value
      );
    }

    return SortMode.none;
  }

  Future<String?> globalTaskFilter() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_globalTaskFilterKey);
  }

  Future<DateTime?> zeroDate() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var dateTime = sharedPreferences.getString(_zeroDateKey);
    if (dateTime != null) {
      return DateTime.parse(dateTime);
    }
    return null;
  }

  Future<int> rateDialogCounter() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getInt(_rateDialogCounterKey) ?? 0;
  }

  Future<void> updateRateDialogCounter(int counter) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setInt(_rateDialogCounterKey, counter);
  }

  Future<void> updateZeroDate(DateTime? zeroDate) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (zeroDate == null) {
      sharedPreferences.remove(_zeroDateKey);
    } else {
      sharedPreferences.setString(_zeroDateKey, zeroDate.toIso8601String());
    }
  }

  /// Persists the user's preferred ThemeMode to local or remote storage.
  Future<void> updateThemeMode(ThemeMode theme) async {
    //TODO not implemented: savidng theme
  }

  Future<void> updateViewMode(ViewMode viewMode) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString(_viewModeKey, viewMode.toString());
  }

  Future<void> updateSortMode(SortMode sortMode) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString(_sortModeKey, sortMode.toString());
  }

  Future<void> updateVaultDirectory(String? vaultDirectory) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (vaultDirectory == null) {
      sharedPreferences.remove(_vaultDirectoryKey);
    } else {
      sharedPreferences.setString(_vaultDirectoryKey, vaultDirectory);
    }
  }

  Future<void> updateVaultName(String? vaultName) async {
    var sharedPreferences = await SharedPreferences.getInstance();

    NotesWidgetConfigCubit.updateWidgetWithVaultInfo();

    if (vaultName == null) {
      sharedPreferences.remove(_vaultNameKey);
    } else {
      sharedPreferences.setString(_vaultNameKey, vaultName);
    }
  }

  // Future<void> updateNotificationTime(DateTime? notificationTime) async {
  //   var sharedPreferences = await SharedPreferences.getInstance();
  //   if (notificationTime == null) {
  //     sharedPreferences.remove(_notificationTimeKey);
  //   } else {
  //     sharedPreferences.setString(_notificationTimeKey,
  //         DateFormat(_notifTimeTemplate).format(notificationTime));
  //   }
  // }

  Future<void> updateTasksFile(String tasksFile) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString(_tasksFileKey, tasksFile);
  }

  Future<void> updateDateTemplate(String dateTemplate) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString(_dateTemplateKey, dateTemplate);
  }

  Future<void> updateDataViewDefaultMarkdownFormat(bool value) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool(_dataViewDefaultMarkdownFormatKey, value);
  }

  Future<void> updateGlobalTaskFilter(String? globalTaskFilter) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (globalTaskFilter == null) {
      sharedPreferences.remove(_globalTaskFilterKey);
    } else {
      sharedPreferences.setString(_globalTaskFilterKey, globalTaskFilter);
    }
  }

  Future<bool> showOverdueOnly() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(_showOverdueOnlyKey) ?? false;
  }

  Future<void> updateShowOverdueOnly(bool value) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool(_showOverdueOnlyKey, value);
  }

  Future<bool> includeDueTasksInToday() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(_includeDueTasksInTodayKey) ?? true;
  }

  Future<void> updateIncludeDueTasksInToday(bool value) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool(_includeDueTasksInTodayKey, value);
  }

  Future<bool> onboardingComplete() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> updateOnboardingComplete(bool value) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool(_onboardingCompleteKey, value);
  }

  Future<String?> subscriptionStatus() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_subscriptionStatusKey);
  }

  Future<void> updateSubscriptionStatus(String? status) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (status == null) {
      sharedPreferences.remove(_subscriptionStatusKey);
    } else {
      sharedPreferences.setString(_subscriptionStatusKey, status);
    }
  }

  Future<DateTime?> subscriptionExpiry() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var dateTime = sharedPreferences.getString(_subscriptionExpiryKey);
    if (dateTime != null) {
      return DateTime.parse(dateTime);
    }
    return null;
  }

  Future<void> updateSubscriptionExpiry(DateTime? expiry) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (expiry == null) {
      sharedPreferences.remove(_subscriptionExpiryKey);
    } else {
      sharedPreferences.setString(
          _subscriptionExpiryKey, expiry.toIso8601String());
    }
  }

  Future<DateTime?> reviewTasksReminderTime() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var timeString = sharedPreferences.getString(_reviewTasksReminderTimeKey);
    if (timeString != null) {
      return DateTime.parse(timeString);
    }
    return null;
  }

  Future<void> updateReviewTasksReminderTime(DateTime? time) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (time == null) {
      sharedPreferences.remove(_reviewTasksReminderTimeKey);
    } else {
      sharedPreferences.setString(
          _reviewTasksReminderTimeKey, time.toIso8601String());
    }
  }

  Future<DateTime?> reviewCompletedReminderTime() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var timeString =
        sharedPreferences.getString(_reviewCompletedReminderTimeKey);
    if (timeString != null) {
      return DateTime.parse(timeString);
    }
    return null;
  }

  Future<void> updateReviewCompletedReminderTime(DateTime? time) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (time == null) {
      sharedPreferences.remove(_reviewCompletedReminderTimeKey);
    } else {
      sharedPreferences.setString(
          _reviewCompletedReminderTimeKey, time.toIso8601String());
    }
  }

  Future<void> updateChatGptKey(String? chatGptKey) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (chatGptKey == null) {
      sharedPreferences.remove(_chatGptKeyKey);
    } else {
      sharedPreferences.setString(_chatGptKeyKey, chatGptKey);
    }
  }

  Future<String?> saveMarker() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_saveMarkerKey);
  }

  Future<void> updateSaveMarker(String? saveMarker) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (saveMarker == null) {
      sharedPreferences.remove(_saveMarkerKey);
    } else {
      sharedPreferences.setString(_saveMarkerKey, saveMarker);
    }
  }

  Future<bool> chooseFileEnabled() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(_chooseFileEnabledKey) ?? false;
  }

  Future<void> updateChooseFileEnabled(bool value) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool(_chooseFileEnabledKey, value);
  }

  Future<String?> lastSelectedFile() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_lastSelectedFileKey);
  }

  Future<void> updateLastSelectedFile(String? filePath) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (filePath == null) {
      sharedPreferences.remove(_lastSelectedFileKey);
    } else {
      sharedPreferences.setString(_lastSelectedFileKey, filePath);
    }
  }

  Future<String?> filePathPattern() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString(_filePathPatternKey);
  }

  Future<void> updateFilePathPattern(String? pattern) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if (pattern == null) {
      sharedPreferences.remove(_filePathPatternKey);
    } else {
      sharedPreferences.setString(_filePathPatternKey, pattern);
    }
  }

  Future<bool> showAITab() async {
    var sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getBool(_showAITabKey) ?? false;
  }

  Future<void> updateShowAITab(bool value) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool(_showAITabKey, value);
  }
}
