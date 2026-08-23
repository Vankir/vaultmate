import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obsi/src/screens/onboarding/cubit/onboarding_flow_cubit.dart';
import 'package:obsi/src/widgets/obsi_title.dart';

/// Screen 1 of the onboarding sequence. Presents VaultMate's most valuable
/// features as a single scrollable list rather than the swipeable, 3-page
/// carousel it replaces (`lib/src/screens/introduction/onboarding.dart`),
/// per FR-002 / SC-003. There is deliberately no Skip control (FR-008).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _features = <_Feature>[
    _Feature(
      icon: Icons.notifications_active_outlined,
      title: 'Never Forget a Task',
      description:
          'Add time to your tasks in Obsidian and get notifications. '
          'Background monitoring detects vault changes and updates '
          'reminders instantly (switch on in Settings).',
    ),
    _Feature(
      icon: Icons.checklist_outlined,
      title: 'Your Tasks, Everywhere',
      description: 'Your Obsidian tasks and notes at your fingertips. '
          'Add the widgets to your home screen, then open VaultMate to '
          'refresh your tasks.',
    ),
    _Feature(
      icon: Icons.filter_alt_outlined,
      title: 'Filter Your Tasks',
      description: 'Show only required tasks, view overdue tasks, or '
          'filter by tag. Long tap on a tag name to exclude tasks from '
          'the list.',
    ),
  ];

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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'VaultMate - Task Manager for Obsidian vault!',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  for (final feature in _features) _FeatureTile(feature),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        context.read<OnboardingFlowCubit>().next(),
                    child: const Text('Next'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String description;

  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _FeatureTile extends StatelessWidget {
  final _Feature feature;

  const _FeatureTile(this.feature);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(feature.icon,
              size: 32, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
