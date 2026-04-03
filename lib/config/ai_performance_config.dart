/// AI performance configuration. FAST_MODE reduces verbosity for faster responses.
class AiPerformanceConfig {
  static const bool fastMode = true;

  /// Max prompt length before trim (chars).
  static const int maxPromptLength = 1200;

  /// Request timeout (seconds).
  static const int requestTimeoutSeconds = 25;

  /// Retry delay (seconds) on timeout.
  static const double retryBackoffSeconds = 1.5;

  /// Slow call threshold (seconds) for analytics.
  static const int slowCallThresholdSeconds = 8;

  /// Min display time for loading UI (seconds).
  static const double minLoadingDisplaySeconds = 1.5;
}
