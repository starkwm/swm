import AppKit

/// Validates and confirms asynchronous moves between normal desktop Spaces.
@MainActor
final class WindowSpaceTransfer {
  static let shared = WindowSpaceTransfer()
  private static let pollAttempts = 40

  private let spaceProvider: () -> [Space]
  private let membershipProvider: (CGWindowID) -> [UInt64]
  private let submitMove: (CGWindowID, UInt64) throws -> Void
  private let wait: () async throws -> Void
  private var movingWindowIDs = Set<CGWindowID>()

  init(
    spaceProvider: @escaping () -> [Space] = { Spaces.all() },
    membershipProvider: @escaping (CGWindowID) -> [UInt64] = {
      WindowServerClient.shared.spaceIDs(containing: $0)
    },
    submitMove: @escaping (CGWindowID, UInt64) throws -> Void = {
      try WindowSpaceBridge.move(windowID: $0, to: $1)
    },
    wait: @escaping () async throws -> Void = { try await Task.sleep(for: .milliseconds(50)) }
  ) {
    self.spaceProvider = spaceProvider
    self.membershipProvider = membershipProvider
    self.submitMove = submitMove
    self.wait = wait
  }

  /// Return only after membership changes; a submitted request alone is not success.
  @discardableResult
  func move(
    windowID: CGWindowID,
    to target: WindowSpaceTarget,
    isValidWindow: () -> Bool = { true }
  ) async throws -> UInt64 {
    try Task.checkCancellation()

    guard !movingWindowIDs.contains(windowID) else {
      throw IPCCommandError.invalidRequest("window is already moving to another Space: \(windowID)")
    }

    let spaces = spaceProvider()
    let membership = Set(membershipProvider(windowID))

    guard
      membership.count == 1,
      let sourceID = membership.first,
      spaces.contains(where: { $0.id == sourceID && $0.type == .normal })
    else {
      throw IPCCommandError.invalidRequest("window must belong to one normal desktop Space")
    }

    guard let destination = target.space(from: sourceID, spaces: spaces) else {
      throw IPCCommandError.invalidRequest("destination Space not found")
    }

    guard destination.type == .normal else {
      throw IPCCommandError.invalidRequest("destination must be a normal desktop Space")
    }

    guard destination.id != sourceID else { return destination.id }

    guard isValidWindow() else {
      throw IPCCommandError.invalidRequest("window not found: \(windowID)")
    }

    movingWindowIDs.insert(windowID)
    defer { movingWindowIDs.remove(windowID) }

    try submitMove(windowID, destination.id)

    for attempt in 0...Self.pollAttempts {
      try Task.checkCancellation()

      guard isValidWindow() else {
        throw IPCCommandError.invalidRequest(
          "window disappeared during Space movement: \(windowID)"
        )
      }

      if Set(membershipProvider(windowID)) == [destination.id] { return destination.id }

      if attempt < Self.pollAttempts { try await wait() }
    }

    throw IPCCommandError.internalError(
      "timed out moving window \(windowID) to Space \(destination.id); movement was not confirmed"
    )
  }
}

extension WindowSpaceTransfer {
  /// Move a window to a Space without switching to it, then fit it to that Space's display.
  ///
  /// `fit` runs only when the destination Space is on another display. It receives the window's
  /// frame, the frame keeping its relative position on the destination display, and the
  /// destination Space ID.
  @discardableResult
  func move(
    _ window: Window,
    to target: WindowSpaceTarget,
    isValidWindow: () -> Bool,
    fit: (_ frame: CGRect, _ targetFrame: CGRect, _ destinationID: UInt64) throws -> Void
  ) async throws -> UInt64 {
    let destinationID = try await move(
      windowID: window.id,
      to: target,
      isValidWindow: isValidWindow
    )
    guard
      let targetScreen = NSScreen.screen(
        for: WindowServerClient.shared.screenID(for: destinationID)
      ),
      let frame = window.frame(),
      let sourceScreen = NSScreen.screen(containingLargestIntersectionWith: frame),
      sourceScreen.uuid != targetScreen.uuid
    else { return destinationID }

    let targetFrame = WindowDisplayTransfer(
      windowFrame: frame,
      sourceFrame: sourceScreen.axVisibleFrame,
      targetFrame: targetScreen.axVisibleFrame
    ).targetWindowFrame()
    try fit(frame, targetFrame, destinationID)
    return destinationID
  }
}
