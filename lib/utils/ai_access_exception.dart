/// Thrown when backend returns 403 with code DAILY_LIMIT_REACHED.
/// Frontend must stop retry, show paywall, and log event.
class DailyLimitReachedException implements Exception {
  DailyLimitReachedException([this.message]);
  final String? message;
  @override
  String toString() => 'DailyLimitReachedException: ${message ?? "Daily AI limit reached"}';
}
