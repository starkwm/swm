import Testing

@testable import SwmLib

@Suite("DiscoveryRetryPolicy")
struct DiscoveryRetryPolicyTests {
  @Test("delay: doubles up to the maximum and ends after the last retry")
  func delayDoublesUpToTheMaximumAndEndsAfterTheLastRetry() {
    let policy = DiscoveryRetryPolicy.standard
    let delays = (0..<policy.maximumRetries).map { policy.delay(afterRetries: $0) }

    #expect(
      delays
        == [100, 200, 400, 800, 1_600, 3_200, 5_000, 5_000, 5_000, 5_000].map {
          Duration.milliseconds($0)
        }
    )
    #expect(policy.delay(afterRetries: policy.maximumRetries) == nil)
  }
}
