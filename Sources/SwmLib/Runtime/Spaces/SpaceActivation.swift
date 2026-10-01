import StarkSkyLight

/// Validates and confirms activation on the target's managed display.
@MainActor
final class SpaceActivation {
  static let shared = SpaceActivation()
  private static let pollAttempts = 40

  private let snapshotProvider: () throws -> SpaceSnapshot
  private let submitActivation: (UInt64, String, [UInt64]) throws -> Void
  private let wait: () async throws -> Void
  private var activatingDisplayIDs = Set<DisplayID>()

  init(
    snapshotProvider: @escaping () throws -> SpaceSnapshot = {
      try WindowServerClient.spaceClient.get().snapshot()
    },
    submitActivation: @escaping (UInt64, String, [UInt64]) throws -> Void = {
      try SpaceActivationBridge.activate(spaceID: $0, displayID: $1, hiding: $2)
    },
    wait: @escaping () async throws -> Void = { try await Task.sleep(for: .milliseconds(50)) }
  ) {
    self.snapshotProvider = snapshotProvider
    self.submitActivation = submitActivation
    self.wait = wait
  }

  /// A timeout or cancellation after submission does not imply that nothing changed.
  func activate(index: Int) async throws -> SpaceSnapshot {
    try Task.checkCancellation()
    let before = try snapshotProvider()
    guard before.isComplete else {
      throw IPCCommandError.internalError(
        "Space topology is incomplete; try again after the transition"
      )
    }
    let spaceIDs = before.allSpaceIDs
    guard spaceIDs.indices.contains(index) else {
      throw IPCCommandError.invalidRequest("space index out of range: \(index)")
    }
    let targetID = spaceIDs[index]
    guard let display = before.displays.first(where: { $0.spaces.contains { $0.id == targetID } }),
      display.spaces.allSatisfy({ $0.type == .desktop })
    else {
      throw IPCCommandError.invalidRequest(
        "Space activation requires a display containing only normal desktop Spaces"
      )
    }
    guard !activatingDisplayIDs.contains(display.id) else {
      throw IPCCommandError.invalidRequest(
        "Space activation is already in progress on this display"
      )
    }
    guard display.currentSpaceID != targetID else { return before }

    activatingDisplayIDs.insert(display.id)
    defer { activatingDisplayIDs.remove(display.id) }

    try submitActivation(
      targetID.rawValue,
      display.id.rawValue,
      display.spaces.filter { $0.id != targetID }.map(\.id.rawValue)
    )

    for attempt in 0...Self.pollAttempts {
      try Task.checkCancellation()
      let observed: SpaceSnapshot
      do {
        observed = try snapshotProvider()
      } catch {
        throw IPCCommandError.internalError(
          "Space activation was requested, but the resulting state could not be read: \(error)"
        )
      }
      guard let currentDisplay = observed.displays.first(where: { $0.id == display.id }),
        currentDisplay.spaces.contains(where: { $0.id == targetID })
      else {
        throw IPCCommandError.internalError(
          "Space activation was requested, but the target Space or display disappeared"
        )
      }
      if currentDisplay.currentSpaceID == targetID { return observed }
      if attempt < Self.pollAttempts { try await wait() }
    }

    throw IPCCommandError.internalError(
      "timed out activating Space \(targetID.rawValue); activation was requested but not confirmed"
    )
  }
}
