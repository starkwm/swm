/// Number of waits allowed while confirming an asynchronous Space change.
private let confirmationWaits = 40

/// Check for a confirmed result, waiting between checks, until one is found or the waits run out.
///
/// Cancellation is checked before every check. Returns nil when the result was never confirmed.
@MainActor
func pollUntilConfirmed<Result>(
  wait: () async throws -> Void,
  check: () throws -> Result?
) async throws -> Result? {
  for attempt in 0...confirmationWaits {
    try Task.checkCancellation()
    if let result = try check() { return result }
    if attempt < confirmationWaits { try await wait() }
  }
  return nil
}
