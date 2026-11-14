/// Backoff schedule for retrying discovery of a process that is not ready to be managed.
struct DiscoveryRetryPolicy: Equatable {
  /// Daemon schedule: 100 ms doubling to 5 s, about 26 s across all 10 retries.
  static let standard = DiscoveryRetryPolicy(
    initialDelay: .milliseconds(100),
    maximumDelay: .seconds(5),
    maximumRetries: 10
  )

  /// Delay before the first retry.
  let initialDelay: Duration

  /// Longest delay between two retries.
  let maximumDelay: Duration

  /// Number of retries allowed before discovery gives up.
  let maximumRetries: Int

  /// Return the delay before the next retry, or nil once every retry has been used.
  func delay(afterRetries retries: Int) -> Duration? {
    guard retries < maximumRetries else { return nil }

    var delay = initialDelay
    for _ in 0..<retries where delay < maximumDelay {
      delay *= 2
    }
    return min(delay, maximumDelay)
  }
}
