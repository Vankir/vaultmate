import 'package:flutter/material.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/ai_assistant/ai_assistant.dart';
import 'package:obsi/src/screens/ai_assistant/cubit/ai_assistant_cubit.dart';

import 'package:obsi/src/screens/settings/settings_view.dart';
import 'package:obsi/src/core/tasks/task_manager.dart';
import 'package:obsi/src/screens/inbox_tasks/cubit/inbox_tasks_cubit.dart';
import 'package:obsi/src/screens/inbox_tasks/inbox_tasks.dart';
import 'package:obsi/src/screens/subscription/subscription_screen.dart';
import 'package:obsi/src/widgets/obsi_title.dart';

class MainNavigator extends StatefulWidget {
  final int _currentScreen;
  final TaskManager taskManager;
  const MainNavigator(this._currentScreen, this.taskManager, {super.key});

  @override
  State<StatefulWidget> createState() {
    return _MainNavigatorState();
  }
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentScreen = 0;
  late SettingsController _settings;
  List<Widget> screens = [];
  late AIAssistantCubit _aiAssistantCubit;

  @override
  void initState() {
    super.initState();
    _settings = SettingsController.getInstance();
    _aiAssistantCubit = AIAssistantCubit(widget.taskManager);
    _updateScreens();
    _currentScreen = widget._currentScreen;

    // Listen to settings changes to update the navigation when subscription status changes
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _aiAssistantCubit.close();
    super.dispose();
  }

  /// Switch to AI tab and send a message
  void switchToAIWithMessage(String message) {
    if (!_settings.showAITab) return; // Don't switch if AI tab is hidden
    setState(() {
      _currentScreen = 2;
    });
    // Send message after a short delay to ensure UI is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      _aiAssistantCubit.sendMessage(message);
    });
  }

  void _onSettingsChanged() {
    setState(() {
      _updateScreens();
      // If AI tab was hidden and user was on it, switch to first tab
      if (!_settings.showAITab && _currentScreen == 2) {
        _currentScreen = 0;
      }
      // If user now has premium and was on premium tab, switch to first tab
      // Account for AI tab being shown or hidden
      int premiumTabIndex = _settings.showAITab ? 3 : 2;
      if (_settings.hasActiveSubscription &&
          _currentScreen >= premiumTabIndex) {
        _currentScreen = 0;
      }
    });
  }

  void _updateScreens() {
    screens = [
      InboxTasks(InboxTasksCubit(widget.taskManager, true)),
      InboxTasks(InboxTasksCubit(widget.taskManager, false)),
    ];

    // Only add AI screen if showAITab is enabled
    if (_settings.showAITab) {
      screens.add(AIAssistant(_aiAssistantCubit));
    }

    // Only add subscription screen if user doesn't have active subscription
    if (!_settings.hasActiveSubscription) {
      screens.add(SubscriptionScreen(settingsController: _settings));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create navigation items based on subscription status
    List<BottomNavigationBarItem> navigationItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.today), label: "Today"),
      const BottomNavigationBarItem(icon: Icon(Icons.inbox), label: "Inbox"),
    ];

    // Only show AI tab if showAITab is enabled
    if (_settings.showAITab) {
      navigationItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.bubble_chart), label: "AI"));
    }

    // Only show Premium tab if user doesn't have active subscription
    if (!_settings.hasActiveSubscription) {
      navigationItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.star), label: "Premium"));
    }

    return Scaffold(
      appBar: AppBar(
        title: const ObsiTitle(),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            SettingsView(controller: _settings)));
              },
              icon: const Icon(Icons.settings))
        ],
      ),
      body: screens[_currentScreen],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: navigationItems,
        currentIndex: _currentScreen,
        onTap: (index) {
          setState(() {
            _currentScreen = index;
          });
        },
      ),
    );
  }
}
