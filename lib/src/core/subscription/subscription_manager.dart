import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logger/logger.dart';

enum SubscriptionStatus {
  unknown,
  active,
  expired,
  pending,
  canceled,
}

class SubscriptionManager extends ChangeNotifier {
  static SubscriptionManager? _instance;
  static SubscriptionManager get instance {
    _instance ??= SubscriptionManager._();
    return _instance!;
  }

  SubscriptionManager._();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final Logger _logger = Logger();

  // Product IDs for your subscription tiers
  static const String monthlySubscriptionId = 'obsi_monthly_premium';
  static const String yearlySubscriptionId = 'obsi_yearly_premium';
  static const String lifetimeSubscriptionId = 'obsi_lifetime_premium';

  // Set of product IDs for all subscription products
  static const Set<String> _productIds = {
    monthlySubscriptionId,
    yearlySubscriptionId,
    lifetimeSubscriptionId,
  };

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  SubscriptionStatus _subscriptionStatus = SubscriptionStatus.unknown;
  bool _hasActiveSubscription = false;

  // Debug flag to bypass subscription checks during development
  // Set to false before releasing to production!
  static const bool _debugUnlockPremium =
      kDebugMode; // Automatically true in debug builds

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  List<PurchaseDetails> get purchases => _purchases;
  SubscriptionStatus get subscriptionStatus => _subscriptionStatus;
  bool get hasActiveSubscription =>
      _debugUnlockPremium || _hasActiveSubscription;

  /// Opaque purchase-verification token for an active monthly or yearly
  /// purchase, or null if there isn't one. Deliberately excludes the
  /// lifetime tier — a one-time purchase doesn't fund the managed
  /// DeepSeek option's ongoing per-request cost (see spec Clarifications,
  /// FR-010/FR-011). The receiving server — not this getter — is the one
  /// that actually verifies this token; this only decides whether the
  /// client believes it's worth sending.
  String? get recurringEntitlementProof {
    for (final purchase in _purchases) {
      if (purchase.productID == monthlySubscriptionId ||
          purchase.productID == yearlySubscriptionId) {
        return purchase.verificationData.localVerificationData;
      }
    }
    return null;
  }

  bool get hasRecurringSubscription => recurringEntitlementProof != null;

  Future<void> initialize() async {
    try {
      // Check if in-app purchases are available
      _isAvailable = await _inAppPurchase.isAvailable();

      if (!_isAvailable) {
        _logger.w('In-app purchases not available');
        return;
      }

      // Listen to purchase updates
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _logger.i('Purchase stream closed'),
        onError: (error) => _logger.e('Purchase stream error: $error'),
      );

      // Load products
      await _loadProducts();

      // Restore previous purchases
      await restorePurchases();

      _logger.i('SubscriptionManager initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize SubscriptionManager: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        _logger.w('Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      notifyListeners();

      _logger.i('Loaded ${_products.length} products');
    } catch (e) {
      _logger.e('Failed to load products: $e');
    }
  }

  Future<bool> purchaseSubscription(String productId) async {
    if (!_isAvailable) {
      _logger.w('In-app purchases not available');
      return false;
    }

    final ProductDetails? product =
        _products.where((p) => p.id == productId).firstOrNull;

    if (product == null) {
      _logger.w('Product not found: $productId');
      return false;
    }

    try {
      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: product);
      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      _logger.i('Purchase initiated for $productId: $success');
      return success;
    } catch (e) {
      _logger.e('Failed to purchase $productId: $e');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      _logger.i('Purchases restored');
    } catch (e) {
      _logger.e('Failed to restore purchases: $e');
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      _handlePurchase(purchaseDetails);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    _logger.i(
        'Handling purchase: ${purchaseDetails.productID}, status: ${purchaseDetails.status}');

    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        _subscriptionStatus = SubscriptionStatus.pending;
        break;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        // Verify the purchase (implement server-side validation in production)
        if (await _verifyPurchase(purchaseDetails)) {
          _subscriptionStatus = SubscriptionStatus.active;
          _hasActiveSubscription = true;

          // Add to purchases list if not already present
          if (!_purchases
              .any((p) => p.purchaseID == purchaseDetails.purchaseID)) {
            _purchases.add(purchaseDetails);
          }
        }

        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        break;

      case PurchaseStatus.error:
        _logger.e('Purchase error: ${purchaseDetails.error}');
        _subscriptionStatus = SubscriptionStatus.unknown;
        break;

      case PurchaseStatus.canceled:
        _logger.i('Purchase canceled');
        _subscriptionStatus = SubscriptionStatus.canceled;
        break;
    }

    notifyListeners();
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // TODO: Implement server-side purchase verification
    // For now, we'll do basic client-side verification

    try {
      // Check if the product ID is valid
      if (!_productIds.contains(purchaseDetails.productID)) {
        _logger.w('Invalid product ID: ${purchaseDetails.productID}');
        return false;
      }

      // Check if we have verification data
      if (purchaseDetails.verificationData.localVerificationData.isEmpty) {
        _logger.w('No verification data available');
        return false;
      }

      // In production, send verification data to your server
      // and verify with Apple/Google servers

      _logger.i('Purchase verified: ${purchaseDetails.productID}');
      return true;
    } catch (e) {
      _logger.e('Purchase verification failed: $e');
      return false;
    }
  }

  ProductDetails? getProduct(String productId) {
    return _products.where((p) => p.id == productId).firstOrNull;
  }

  bool isSubscriptionActive() {
    return _debugUnlockPremium ||
        (_hasActiveSubscription &&
            _subscriptionStatus == SubscriptionStatus.active);
  }

  void checkSubscriptionExpiration() {
    // TODO: Implement subscription expiration checking
    // This should check with your server or platform stores
    // to verify if the subscription is still active
  }

  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
