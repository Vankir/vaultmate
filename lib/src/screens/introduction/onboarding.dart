import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:obsi/src/widgets/obsi_title.dart';

/// Make sure you have added introduction_screen to your pubspec.yaml dependencies:
/// introduction_screen: ^3.1.2

class OnboardingPage extends StatefulWidget {
  final Function(bool dontShowAgain) onDone;
  const OnboardingPage({super.key, required this.onDone});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _dontShowAgain = false;

  Widget _buildCheckbox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Checkbox(
            value: _dontShowAgain,
            onChanged: (value) {
              setState(() {
                _dontShowAgain = value ?? false;
              });
            },
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _dontShowAgain = !_dontShowAgain;
              });
            },
            child: const Text(
              "Don't show on-boarding again",
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
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
              child: IntroductionScreen(
                pages: [
                  PageViewModel(
                    title: "Never Forget a Task",
                    bodyWidget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            "Add time to your tasks in Obsidian and get notifications.\n\nBackground monitoring detects changes in vault and updates reminders instantly (switch on in settings).",
                            style: TextStyle(fontSize: 17),
                            textAlign: TextAlign.center),
                        _buildCheckbox()
                      ],
                    ),
                    image: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 5.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/onboarding_notif.png',
                            width: 280,
                            height: 280,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PageViewModel(
                    title: "VaultMate - Task Manager for Obsidian vault!",
                    bodyWidget: Text(
                        "Your Obsidian tasks and notes at your fingertips.\n\nAdd the widgets to your home screen, then open VaultMate to refresh your tasks.",
                        style: TextStyle(fontSize: 17),
                        textAlign: TextAlign.center),
                    image: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 5.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/onboarding_widget.png',
                            width: 280,
                            height: 280,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PageViewModel(
                    title: "Filter Your Tasks",
                    bodyWidget: Text(
                        "Show only required tasks, view overdue tasks, or filter by tag.\n\nLong tap on a tag name to exclude tasks from the list.",
                        style: TextStyle(fontSize: 17),
                        textAlign: TextAlign.center),
                    image: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 5.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/onboarding_filters.png',
                            width: 280,
                            height: 280,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                onDone: () async {
                  widget.onDone(_dontShowAgain);
                },
                onSkip: () async {
                  widget.onDone(_dontShowAgain);
                },
                showSkipButton: true,
                skip: const Text("Skip"),
                next: const Icon(Icons.arrow_forward),
                done: const Text("Done",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                dotsDecorator: const DotsDecorator(
                  activeColor: Color(0xFF3B82F6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
