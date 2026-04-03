/// Monetization constants. Do not hardcode these in business logic.
class MonetizationConfig {
  MonetizationConfig._();

  static const int trialDaysCount = 7;
  static const int dailyFreeUsesLimit = 2;
  /// Daily reset interval in hours.
  static const int dailyResetHours = 24;
}
