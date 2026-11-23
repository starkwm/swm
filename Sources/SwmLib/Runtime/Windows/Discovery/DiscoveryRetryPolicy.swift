struct DiscoveryRetryPolicy: Equatable {
  static let standard = DiscoveryRetryPolicy(
    initialDelay: .milliseconds(100),
    maximumDelay: .seconds(5),
    maximumRetries: 10
  )

  let initialDelay: Duration

  let maximumDelay: Duration

  let maximumRetries: Int

  func delay(afterRetries retries: Int) -> Duration? {
    guard retries < maximumRetries else { return nil }

    var delay = initialDelay
    for _ in 0..<retries where delay < maximumDelay {
      delay *= 2
    }
    return min(delay, maximumDelay)
  }
}
