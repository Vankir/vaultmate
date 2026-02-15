import 'dart:io';

import 'package:external_path/external_path.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:intl/intl.dart';
import 'package:obsi/src/core/utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:obsi/src/screens/subscription/subscription_screen.dart';

import 'settings_controller.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.controller});

  static const routeName = '/settings';

  final SettingsController controller;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _dateTemplateController = TextEditingController();
  final _tasksFileNameController = TextEditingController();
  final _globalTaskFilterController = TextEditingController();
  final _saveMarkerController = TextEditingController();
  final _filePathPatternController = TextEditingController();

  @override
  void initState() {
    _dateTemplateController.text = widget.controller.dateTemplate;
    _tasksFileNameController.text = widget.controller.tasksFile;
    _globalTaskFilterController.text = widget.controller.globalTaskFilter;
    _saveMarkerController.text = widget.controller.saveMarker ?? '';
    _filePathPatternController.text = widget.controller.filePathPattern ?? '';

    _dateTemplateController.addListener(() {
      widget.controller.updateDateTemplate(_dateTemplateController.text);
    });

    // Listen to controller changes and rebuild UI when needed
    widget.controller.addListener(_onControllerChanged);

    super.initState();
  }

  void _onControllerChanged() {
    setState(() {
      // Trigger rebuild when controller notifies changes
    });
  }

  @override
  void dispose() {
    _tasksFileNameController.dispose();
    _dateTemplateController.dispose();
    _globalTaskFilterController.dispose();
    _saveMarkerController.dispose();
    _filePathPatternController.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(children: [
          // Padding(
          //   padding: const EdgeInsets.all(16),
          //   // Glue the SettingsController to the theme selection DropdownButton.
          //   //
          //   // When a user selects a theme from the dropdown list, the
          //   // SettingsController is updated, which rebuilds the MaterialApp.
          //   child: DropdownButton<ThemeMode>(
          //     // Read the selected themeMode from the controller
          //     value: widget.controller.themeMode,
          //     // Call the updateThemeMode method any time the user selects a theme.
          //     onChanged: widget.controller.updateThemeMode,
          //     items: const [
          //       DropdownMenuItem(
          //         value: ThemeMode.system,
          //         child: Text('System Theme'),
          //       ),
          //       DropdownMenuItem(
          //         value: ThemeMode.light,
          //         child: Text('Light Theme'),
          //       ),
          //       DropdownMenuItem(
          //         value: ThemeMode.dark,
          //         child: Text('Dark Theme'),
          //       )
          //     ],
          //   ),
          // ),

          // Padding(
          //     padding: const EdgeInsets.all(16),
          //     child: Column(children: [
          //       const Align(
          //           alignment: Alignment.centerLeft,
          //           child: Text("Date format used in Obsidian: ")),
          //       TextField(
          //         controller: _dateTemplateController,
          //       )
          //     ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        "File name for adding new tasks (located at the path below):")),
                TextField(
                  controller: _tasksFileNameController,
                  onSubmitted: (value) {
                    widget.controller.updateTasksFile(value);
                  },
                )
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Global Task Filter: ")),
                TextField(
                  controller: _globalTaskFilterController,
                  decoration: const InputDecoration(
                    hintText: "Enter a global task filter, e.g. #task",
                  ),
                  onSubmitted: (value) {
                    widget.controller.updateGlobalTaskFilter(value);
                  },
                )
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Dataview default markdown format:")),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use Dataview format when saving tasks'),
                  subtitle: const Text('Disable to use Emoji format'),
                  value: widget.controller.dataViewDefaultMarkdownFormat,
                  onChanged: (value) {
                    widget.controller
                        .updateDataViewDefaultMarkdownFormat(value);
                  },
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Save Marker (for file selection): ")),
                TextField(
                  controller: _saveMarkerController,
                  decoration: const InputDecoration(
                    hintText: "Enter a marker, e.g. <!-- tasks -->",
                  ),
                  onSubmitted: (value) {
                    widget.controller
                        .updateSaveMarker(value.isEmpty ? null : value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  "When 'Choose file' is enabled, new tasks will be inserted after this marker in the selected file.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        "File Path Pattern (for automatic file selection): ")),
                TextField(
                  controller: _filePathPatternController,
                  decoration: const InputDecoration(
                    hintText: "e.g. {vault}/Daily notes/{yyyy-MM-dd}.md",
                  ),
                  onSubmitted: (value) {
                    widget.controller
                        .updateFilePathPattern(value.isEmpty ? null : value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  "If specified, tasks will be saved to this file path instead of showing file picker. Use {vault} for vault root. Date patterns must be in brackets: {yyyy-MM-dd}, {yyyy}/{MM}/{dd}, etc.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Show AI Assistant tab:")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Enable AI Assistant tab in the bottom navigation",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Switch(
                      value: widget.controller.showAITab,
                      onChanged: (value) {
                        widget.controller.updateShowAITab(value);
                        setState(() {
                          // Trigger UI rebuild after setting update
                        });
                      },
                    ),
                  ],
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Include tasks with today due day:")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Show tasks that are due today in the 'Today' view",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Switch(
                      value: widget.controller.includeDueTasksInToday,
                      onChanged: (value) {
                        widget.controller.updateIncludeDueTasksInToday(value);
                        setState(() {
                          // Trigger UI rebuild after setting update
                        });
                      },
                    ),
                  ],
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Show on-boarding screen:")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Enable to show the on-boarding screen when the app starts",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Switch(
                      value: !widget.controller.onboardingComplete,
                      onChanged: (value) {
                        widget.controller.updateOnboardingComplete(!value);
                        setState(() {
                          // Trigger UI rebuild after setting update
                        });
                      },
                    ),
                  ],
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Daily reminder to review tasks:")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("Time: "),
                    addDateTimePicker(
                      widget.controller.reviewTasksReminderTime != null
                          ? Text(
                              DateFormat('HH:mm').format(
                                  widget.controller.reviewTasksReminderTime!),
                              style: const TextStyle(fontSize: 16),
                            )
                          : Text(
                              'Not set',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                      widget.controller.reviewTasksReminderTime ??
                          DateTime.now(),
                      context,
                      (time) {
                        widget.controller.updateReviewTasksReminderTime(time);
                        setState(() {
                          // Trigger UI rebuild after time update
                        });
                      },
                      timePicker: true,
                    ),
                    if (widget.controller.reviewTasksReminderTime != null)
                      IconButton(
                        onPressed: () {
                          widget.controller.updateReviewTasksReminderTime(null);
                          setState(() {
                            // Trigger UI rebuild after clearing time
                          });
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear reminder',
                      ),
                  ],
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Daily reminder to review completed tasks:")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text("Time: "),
                    addDateTimePicker(
                      widget.controller.reviewCompletedReminderTime != null
                          ? Text(
                              DateFormat('HH:mm').format(widget
                                  .controller.reviewCompletedReminderTime!),
                              style: const TextStyle(fontSize: 16),
                            )
                          : Text(
                              'Not set',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                      widget.controller.reviewCompletedReminderTime ??
                          DateTime.now(),
                      context,
                      (time) {
                        widget.controller
                            .updateReviewCompletedReminderTime(time);
                        setState(() {
                          // Trigger UI rebuild after time update
                        });
                      },
                      timePicker: true,
                    ),
                    if (widget.controller.reviewCompletedReminderTime != null)
                      IconButton(
                        onPressed: () {
                          widget.controller
                              .updateReviewCompletedReminderTime(null);
                          setState(() {
                            // Trigger UI rebuild after clearing time
                          });
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear reminder',
                      ),
                  ],
                ),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            "Folder in the Obsidian vault containing tasks:"))),
                Text(widget.controller.vaultDirectory ??
                    "<Please choose the folder>")
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                  child: const Text("Select"),
                  onPressed: () async {
                    var vaultDirectory =
                        await SettingsController.selectVaultDirectory(context);

                    if (vaultDirectory != null) {
                      widget.controller.updateVaultDirectory(vaultDirectory);
                    }
                  })),

          // Subscription Section
          Platform.isIOS
              ? SizedBox()
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        widget.controller.hasActiveSubscription
                            ? Icons.star
                            : Icons.star_border,
                        color: widget.controller.hasActiveSubscription
                            ? Colors.amber
                            : Colors.grey,
                      ),
                      title: Text(
                        widget.controller.hasActiveSubscription
                            ? 'Premium Active'
                            : 'Upgrade to Premium',
                      ),
                      subtitle: Text(
                        widget.controller.hasActiveSubscription
                            ? 'Manage your subscription'
                            : 'Unlock all features',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          SubscriptionScreen.routeName,
                          arguments: widget.controller,
                        );
                      },
                    ),
                  ),
                ),

          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text("Contact the developer:"),
                GestureDetector(
                  onTap: () {
                    _launchEmail(context);
                  },
                  child: const Text("support@vaultmate.app",
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      )),
                )
              ])),

          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const SizedBox(height: 1),
                FutureBuilder<String>(
                  future: widget.controller.getAppVersion(),
                  builder: (context, snapshot) {
                    return Text(
                      'Version: ${snapshot.data ?? 'Loading...'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    );
                  },
                ),
              ])),
        ]),
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: "support@vaultmate.app",
      query: 'subject=VaultMate', // Optional query parameters
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $emailUri')),
      );
    }
  }
}
