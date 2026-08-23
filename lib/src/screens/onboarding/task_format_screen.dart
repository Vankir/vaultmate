import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obsi/src/screens/onboarding/cubit/onboarding_flow_cubit.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/widgets/obsi_title.dart';

/// Screen 2 of the onboarding sequence. Explains, in plain language, what
/// "Inline tasks" and "TaskNotes" mean for how tasks are stored (FR-003),
/// lets the user pick a default (FR-004), and persists it on proceed
/// (FR-005). "Inline tasks" is pre-selected so the user can proceed without
/// actively deciding (FR-004/FR-016) — there is no Skip control (FR-008).
class TaskFormatScreen extends StatefulWidget {
  const TaskFormatScreen({super.key});

  @override
  State<TaskFormatScreen> createState() => _TaskFormatScreenState();
}

class _TaskFormatScreenState extends State<TaskFormatScreen> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = SettingsController.getInstance().taskFormatPreference;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const ObsiTitle()),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'How should VaultMate save your tasks?',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choose a default. You can change this later in '
                    'Settings, and you can always pick a different option '
                    'for an individual task.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 24),
                  RadioGroup<String>(
                    groupValue: _selected,
                    onChanged: (value) {
                      if (value != null) _select(value);
                    },
                    child: const Column(
                      children: [
                        _OptionCard(
                          title: 'Inline tasks',
                          description: 'Tasks are added as checklist items '
                              'inside a note, alongside your other content '
                              '— compatible with the Tasks plugin.',
                          value: 'inline',
                        ),
                        _OptionCard(
                          title: 'TaskNotes',
                          description: 'Each task gets its own separate '
                              'note file in your vault — compatible with '
                              'the TaskNotes plugin.',
                          value: 'taskNote',
                        ),
                        _OptionCard(
                          title: 'Both',
                          description:
                              "Don't set a default — choose the format "
                              'individually each time you create a task, '
                              'exactly as VaultMate works today.',
                          value: 'both',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          context.read<OnboardingFlowCubit>().back(),
                      child: const Text('Back'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _proceed,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(String value) {
    setState(() => _selected = value);
  }

  void _proceed() {
    SettingsController.getInstance().updateTaskFormatPreference(_selected);
    context.read<OnboardingFlowCubit>().next();
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String description;
  final String value;

  const _OptionCard({
    required this.title,
    required this.description,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: RadioListTile<String>(
        value: value,
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
      ),
    );
  }
}
