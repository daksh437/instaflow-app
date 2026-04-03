class PaymentService {
  /// Start payment process with Razorpay
  /// 
  /// [plan] - 'basic' or 'pro'
  /// [duration] - '1m', '3m', '6m', or '12m'
  Future<void> startPayment({
    required String plan,
    required String duration,
    required Function(bool success) onResult,
  }) async {
    try {
      print("💳 Starting payment for $plan - $duration");
      
      // TODO: Integrate Razorpay SDK
      // 
      // Steps:
      // 1. Initialize Razorpay
      // 2. Create order
      // 3. Open Razorpay checkout
      // 4. Handle payment success/failure
      // 5. Call onResult(true) on success
      // 6. Call onResult(false) on failure
      
      // Placeholder: Simulate payment after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      
      // For now, return success (replace with actual Razorpay integration)
      print("✅ Payment successful (placeholder)");
      onResult(true);
      
      // Example Razorpay integration structure:
      /*
      final razorpay = Razorpay();
      
      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
        print("Payment Success: ${response.paymentId}");
        onResult(true);
      });
      
      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
        print("Payment Error: ${response.message}");
        onResult(false);
      });
      
      final options = {
        'key': 'YOUR_RAZORPAY_KEY',
        'amount': getPrice(plan, duration) * 100, // in paise
        'name': 'InstaFlow',
        'description': 'Premium Subscription',
        'prefill': {
          'email': userEmail,
          'contact': userPhone,
        },
      };
      
      razorpay.open(options);
      */
    } catch (e) {
      print("❌ Payment error: $e");
      onResult(false);
    }
  }

  /// Do not use for display — prices come from ProductDetails only. Returns 0 for compatibility.
  static int getPrice(String plan, String duration) {
    return 0;
  }

  /// Do not use for display — use ProductDetails.price from SubscriptionService. Returns placeholder.
  static String getFormattedPrice(String plan, String duration) {
    return '—';
  }

  /// Get savings percentage for longer durations
  static int getSavingsPercentage(String plan, String duration) {
    final monthlyPrice = getPrice(plan, '1m');
    final currentPrice = getPrice(plan, duration);
    final months = _getMonthsFromDuration(duration);
    
    final totalMonthlyPrice = monthlyPrice * months;
    if (totalMonthlyPrice <= currentPrice) return 0;
    
    final savings = ((totalMonthlyPrice - currentPrice) / totalMonthlyPrice * 100).round();
    return savings;
  }

  static int _getMonthsFromDuration(String duration) {
    switch (duration) {
      case '1m':
        return 1;
      case '3m':
        return 3;
      case '6m':
        return 6;
      case '12m':
        return 12;
      default:
        return 1;
    }
  }
}

