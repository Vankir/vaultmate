import 'package:flutter/material.dart';
import 'package:obsi/src/localization/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:obsi/src/screens/onboarding/onboarding_flow.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/subscription/subscription_screen.dart';
import 'package:obsi/src/core/intent_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obsi/src/screens/task_editor/cubit/task_editor_cubit.dart';
import 'package:obsi/src/screens/task_editor/task_editor.dart';
import 'package:obsi/src/core/tasks/task.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'main_navigator.dart' as main_screen;
import 'src/screens/notes_widget_config/notes_widget_config.dart';
import 'src/screens/notes_widget_config/cubit/notes_widget_config_cubit.dart';

class App extends StatefulWidget {
  final SettingsController settingsController;
  final TaskManager taskManager;
  const App(
      {super.key, required this.settingsController, required this.taskManager});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupIntentHandler();
  }

  void _setupIntentHandler() {
    IntentService.instance.setIntentHandler((action, extras) {
      _handleIntent(action, extras);
    });
  }

  void _handleIntent(String action, Map<String, dynamic>? extras) {
    if (widget.settingsController.vaultDirectory == null) {
      return;
    }

    switch (action) {
      case 'add_task':
        SettingsController.getInstance().hasActiveSubscription
            ? _navigateToAddTask()
            : _navigatorKey.currentState
                ?.pushNamed(SubscriptionScreen.routeName);
        break;
      case 'open_task':
        if (extras != null && extras['task_json'] != null) {
          SettingsController.getInstance().hasActiveSubscription
              ? _navigateToOpenTask(extras['task_json'])
              : _navigatorKey.currentState
                  ?.pushNamed(SubscriptionScreen.routeName);
        }
        break;
      case 'open_notes_widget_config':
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => BlocProvider(
              create: (_) => NotesWidgetConfigCubit()..load(),
              child: const NotesWidgetConfig(),
            ),
          ),
        );
        break;
    }
  }

  void _navigateToAddTask() {
    var settings = SettingsController.getInstance();
    var createTasksPath = p.join(settings.vaultDirectory!, settings.tasksFile);

    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => TaskEditorCubit(widget.taskManager,
              task:
                  Task("", created: DateTime.now(), scheduled: DateTime.now()),
              createTasksPath: createTasksPath),
          child: const TaskEditor(),
        ),
      ),
    );
  }

  void _navigateToOpenTask(String taskJson) {
    try {
      final taskData = jsonDecode(taskJson);
      final task = _createTaskFromTaskWrapper(taskData);

      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) =>
                TaskEditorCubit(widget.taskManager, task: task),
            child: const TaskEditor(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error parsing task JSON: $e');
    }
  }

  Task _createTaskFromTaskWrapper(Map<String, dynamic> taskData) {
    // Convert TaskWrapper JSON to Task object
    final filePath = taskData['filePath'] as String?;
    final fileOffset = taskData['fileOffset'] as String?;
    if (filePath == null || fileOffset == null) {
      throw Exception('Invalid task data: $taskData');
    }

    var task = widget.taskManager
        .getTaskByFileAndOffset(filePath, int.parse(fileOffset));
    if (task == null) {
      throw Exception(
          'Task not found for file: $filePath, offset: $fileOffset');
    }

    return task;
  }

  Widget _buildHomeWidget() {
    final settings = widget.settingsController;
    // Single gate replacing the old two independent checks (intro carousel
    // seen, then separately vaultDirectory == null): onboarding is only
    // complete once all 3 screens finish, ending with a valid vault folder.
    if (!settings.onboardingComplete || settings.vaultDirectory == null) {
      return OnboardingFlow(
        settingsController: settings,
        taskManager: widget.taskManager,
      );
    }
    return main_screen.MainNavigator(0, widget.taskManager);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: widget.settingsController,
        builder: (context, _) => MaterialApp(
              navigatorKey: _navigatorKey,
              title: 'Obsi',
              debugShowCheckedModeBanner: false,
              restorationScopeId: 'app',
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en', ''), // English, no country code
              ],

              // Use AppLocalizations to configure the correct application title
              // depending on the user's locale.
              //
              // The appTitle is defined in .arb files found in the localization
              // directory.
              onGenerateTitle: (BuildContext context) =>
                  AppLocalizations.of(context)!.appTitle,

              // Define a light and dark color theme. Then, read the user's
              // preferred ThemeMode (light, dark, or system default) from the
              // SettingsController to display the correct theme.
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF3B82F6),
                  brightness: Brightness.light,
                ),
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF3B82F6),
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),
              themeMode: widget.settingsController.themeMode,
              home: _buildHomeWidget(),
              routes: {
                '/today_tasks': (context) =>
                    main_screen.MainNavigator(0, widget.taskManager),
                '/tasks': (context) =>
                    main_screen.MainNavigator(1, widget.taskManager),
                SubscriptionScreen.routeName: (context) => SubscriptionScreen(
                      settingsController: widget.settingsController,
                    ),
              },
            ));
  }
}
