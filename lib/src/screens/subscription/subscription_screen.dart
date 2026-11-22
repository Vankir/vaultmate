import 'package:flutter/material.dart';
import 'package:obsi/src/core/subscription/premium_features.dart';
import 'package:obsi/src/core/subscription/subscription_manager.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionScreen extends StatefulWidget {
  final SettingsController settingsController;

  const SubscriptionScreen({
    super.key,
    required this.settingsController,
  });

  static const routeName = '/subscription';

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionManager _subscriptionManager = SubscriptionManager.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _subscriptionManager.addListener(_onSubscriptionUpdate);
  }

  @override
  void dispose() {
    _subscriptionManager.removeListener(_onSubscriptionUpdate);
    super.dispose();
  }

  void _onSubscriptionUpdate() {
    if (mounted) {
      setState(() {});

      // Update settings controller when subscription changes
      if (_subscriptionManager.hasActiveSubscription) {
        widget.settingsController.updateSubscriptionStatus('active');

        // Check if user has lifetime subscription
        final hasLifetime = _subscriptionManager.purchases.any((purchase) =>
            purchase.productID == SubscriptionManager.lifetimeSubscriptionId);

        if (hasLifetime) {
          // Lifetime subscription never expires - set to far future date
          widget.settingsController.updateSubscriptionExpiry(
            DateTime(2099, 12, 31),
          );
        } else {
          // Set expiry to 1 year from now for active subscriptions
          // In production, get actual expiry from purchase details
          widget.settingsController.updateSubscriptionExpiry(
            DateTime.now().add(const Duration(days: 365)),
          );
        }
      } else {
        widget.settingsController.updateSubscriptionStatus('inactive');
        widget.settingsController.updateSubscriptionExpiry(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Subscription'),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_subscriptionManager.isAvailable) {
      return const Center(
        child: Text(
          'In-app purchases are not available',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return SafeArea(
      bottom: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentSubscriptionStatus(),
            const SizedBox(height: 24),
            _buildFreeTierFeatures(),
            const SizedBox(height: 16),
            _buildPremiumFeatures(),
            const SizedBox(height: 24),
            _buildSubscriptionPlans(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSubscriptionStatus() {
    final hasActiveSubscription =
        widget.settingsController.hasActiveSubscription;

    // Check if user has lifetime subscription
    final hasLifetime = _subscriptionManager.purchases.any((purchase) =>
        purchase.productID == SubscriptionManager.lifetimeSubscriptionId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasActiveSubscription ? Icons.check_circle : Icons.info,
                  color: hasActiveSubscription ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Subscription Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveSubscription
                  ? (hasLifetime ? 'Lifetime Premium' : 'Premium Active')
                  : 'Free Version',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: hasActiveSubscription ? Colors.green : Colors.grey[600],
              ),
            ),
            if (hasActiveSubscription && hasLifetime)
              Row(
                children: [
                  Icon(Icons.all_inclusive,
                      size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Never expires',
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else if (hasActiveSubscription &&
                widget.settingsController.subscriptionExpiry != null)
              Text(
                'Expires: ${_formatDate(widget.settingsController.subscriptionExpiry!)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeTierFeatures() {
    const freeFeatures = [
      'All your tasks, no limit, in list and grouped views',
      'Add, open and complete tasks from the home-screen widget',
      'Recurring tasks, tags, reminders and TaskNotes format',
      'AI assistant with your own API key',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Free forever',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...freeFeatures.map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFeatures() {
    // Single source of truth: PremiumFeatures.premiumFeaturesList. The old
    // Platform.isIOS branch advertised "Adding task and open task from widget"
    // as paid and "Future premium features" as a benefit - both wrong (widget
    // actions are free since 1.9.0, and an unnamed future feature is not an
    // argument to pay).
    final features = PremiumFeatures.premiumFeaturesList;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Premium Features',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionPlans() {
    if (_subscriptionManager.products.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Loading subscription plans...'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Plan',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ..._subscriptionManager.products
            .map((product) => _buildProductCard(product)),
      ],
    );
  }

  Widget _buildProductCard(ProductDetails product) {
    final isYearly = product.id == SubscriptionManager.yearlySubscriptionId;
    final isLifetime = product.id == SubscriptionManager.lifetimeSubscriptionId;
    final isPopular = isLifetime; // Mark lifetime as most popular

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: isLifetime ? 4 : 1,
      color: isLifetime ? Colors.amber.shade50 : null,
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'BEST VALUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isLifetime ? Colors.amber.shade900 : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      product.price,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isLifetime ? Colors.amber.shade900 : Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  product.description,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (isLifetime) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      '🎉 One-time payment • Lifetime access',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
                if (isYearly) ...[
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading ? null : () => _purchaseProduct(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLifetime ? Colors.amber : null,
                      foregroundColor: isLifetime ? Colors.white : null,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.settingsController.hasActiveSubscription
                                ? (isLifetime
                                    ? 'Upgrade to Lifetime'
                                    : 'Switch to This Plan')
                                : (isLifetime
                                    ? 'Get Lifetime Access'
                                    : 'Subscribe'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (widget.settingsController.hasActiveSubscription) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _restorePurchases,
              child: const Text('Restore Purchases'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextButton(
          onPressed: () => _showTermsAndPrivacy(),
          child: const Text('Terms of Service & Privacy Policy'),
        ),
      ],
    );
  }

  Future<void> _purchaseProduct(ProductDetails product) async {
    setState(() => _isLoading = true); // change to false to test subscription

    try {
      final success =
          await _subscriptionManager.purchaseSubscription(product.id);

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initiate purchase. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);

    try {
      await _subscriptionManager.restorePurchases();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore purchases: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTermsAndPrivacy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Legal Information'),
        content: const Text(
          'Please visit our website for Terms of Service and Privacy Policy details.\n\n'
          'Subscriptions auto-renew unless canceled. You can manage your subscription '
          'in your device\'s App Store settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
