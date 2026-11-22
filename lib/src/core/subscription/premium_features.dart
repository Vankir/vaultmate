import 'package:flutter/material.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/subscription/subscription_screen.dart';

class PremiumFeatures {
  /// What Premium actually unlocks.
  ///
  /// Free tier is deliberately complete for everyday use: unlimited tasks in
  /// list and grouped views, plus adding, opening and completing tasks from the
  /// home-screen widget. Premium adds the calendar planning view and support.
  /// Keep this list in sync with the real gating code - promising
  /// "task synchronization" in an offline app is what users complain about.
  static const List<String> premiumFeaturesList = [
    'Calendar planning view',
    'Support the development of VaultMate',
    'Every future premium feature, included',
  ];

  /// Check if the user has access to premium features
  static bool hasAccess(SettingsController settingsController) {
    return settingsController.hasActiveSubscription;
  }

  /// Show premium feature dialog if user doesn't have access
  static void showPremiumDialog(BuildContext context, {String? featureName}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Premium Feature'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (featureName != null) ...[
              Text(
                '$featureName is a premium feature.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
            ],
            Text('Upgrade to premium to access:'),
            SizedBox(height: 8),
            ...premiumFeaturesList.map(
              (feature) => Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.check, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(feature, style: TextStyle(fontSize: 14))),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(
                context,
                SubscriptionScreen.routeName,
                arguments: SettingsController.getInstance(),
              );
            },
            child: Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  /// Wrapper widget that conditionally shows content based on subscription status
  static Widget conditionalFeature({
    required SettingsController settingsController,
    required Widget child,
    required Widget premiumPrompt,
  }) {
    if (hasAccess(settingsController)) {
      return child;
    } else {
      return premiumPrompt;
    }
  }

  /// Check if a specific feature requires premium access
  static bool isFeaturePremium(String featureKey) {
    const premiumFeatures = {
      'advanced_filtering',
      'custom_notifications',
      'unlimited_sync',
      'priority_support',
    };

    return premiumFeatures.contains(featureKey);
  }

  /// Execute function if user has premium access, otherwise show dialog
  static void executeIfPremium({
    required BuildContext context,
    required SettingsController settingsController,
    required VoidCallback onExecute,
    String? featureName,
  }) {
    if (hasAccess(settingsController)) {
      onExecute();
    } else {
      showPremiumDialog(context, featureName: featureName);
    }
  }
}
