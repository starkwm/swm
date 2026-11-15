private let confirmationWaits = 40

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
