import Testing

@testable import SwmLib

@Suite("WindowSpaceTransfer")
@MainActor
struct WindowSpaceTransferTests {
  @Test("move: waits for destination membership and removal from the source")
  func confirmsMovement() async throws {
    var membership: [UInt64] = [11]
    var waits = 0
    var submitted = false

    let transfer = WindowSpaceTransfer(
      spaceProvider: { spaces },
      membershipProvider: { _ in membership },
      submitMove: { windowID, spaceID in
        #expect(windowID == 42 && spaceID == 33)

        submitted = true
        membership = [11, 33]
      },
      wait: {
        waits += 1
        membership = waits == 1 ? [] : [33]
      }
    )

    let destinationID = try await transfer.move(windowID: 42, to: .next)

    #expect(destinationID == 33)
    #expect(submitted)
    #expect(waits == 2)
  }

  @Test("move: an unchanged membership times out without reporting success")
  func timesOut() async throws {
    var waits = 0

    let transfer = WindowSpaceTransfer(
      spaceProvider: { spaces },
      membershipProvider: { _ in [11] },
      submitMove: { _, _ in },
      wait: { waits += 1 }
    )

    await #expect(
      throws: IPCCommandError.internalError(
        "timed out moving window 42 to Space 33; movement was not confirmed"
      )
    ) {
      try await transfer.move(windowID: 42, to: .next)
    }

    #expect(waits == 40)
  }

  @Test("move: accepts confirmation on the final poll")
  func finalPollConfirmation() async throws {
    var waits = 0

    let transfer = WindowSpaceTransfer(
      spaceProvider: { spaces },
      membershipProvider: { _ in waits == 40 ? [33] : [11] },
      submitMove: { _, _ in },
      wait: { waits += 1 }
    )

    #expect(try await transfer.move(windowID: 42, to: .next) == 33)
  }

  @Test("move: targeting the current desktop does not submit a private operation")
  func currentDesktop() async throws {
    let transfer = WindowSpaceTransfer(
      spaceProvider: { spaces },
      membershipProvider: { _ in [11] },
      submitMove: { _, _ in Issue.record("unexpected submission") },
      wait: { Issue.record("unexpected wait") }
    )

    let destinationID = try await transfer.move(windowID: 42, to: .index(0))

    #expect(destinationID == 11)
  }

  @Test("move: rejects fullscreen destinations and missing indexes")
  func invalidDestinations() async {
    let transfer = WindowSpaceTransfer(
      spaceProvider: { spaces },
      membershipProvider: { _ in [11] },
      submitMove: { _, _ in Issue.record("unexpected submission") }
    )

    await #expect(
      throws: IPCCommandError.invalidRequest("destination must be a normal desktop Space")
    ) {
      try await transfer.move(windowID: 42, to: .index(1))
    }

    await #expect(throws: IPCCommandError.invalidRequest("destination Space not found")) {
      try await transfer.move(windowID: 42, to: .index(99))
    }
  }

  @Test(
    "move: rejects unknown, fullscreen, and sticky source windows",
    arguments: [[], [22], [99], [11, 33]]
  )
  func invalidSources(membership: [UInt64]) async {
    let transfer = WindowSpaceTransfer(
      spaceProvider: { spaces },
      membershipProvider: { _ in membership },
      submitMove: { _, _ in Issue.record("unexpected submission") }
    )

    await #expect(
      throws: IPCCommandError.invalidRequest("window must belong to one normal desktop Space")
    ) {
      try await transfer.move(windowID: 42, to: .next)
    }
  }

  @Test("move: reports an unavailable bridge without waiting")
  func unavailableBridge() async {
    let transfer = WindowSpaceTransfer(
      spaceProvider: { spaces },
      membershipProvider: { _ in [11] },
      submitMove: { _, _ in throw WindowSpaceBridgeError.unavailable },
      wait: { Issue.record("unexpected wait") }
    )

    await #expect(throws: WindowSpaceBridgeError.unavailable) {
      try await transfer.move(windowID: 42, to: .next)
    }
  }

  @Test("move: detects a window that disappears while waiting")
  func disappearedWindow() async {
    var valid = true

    let transfer = WindowSpaceTransfer(
      spaceProvider: { spaces },
      membershipProvider: { _ in [11] },
      submitMove: { _, _ in },
      wait: { valid = false }
    )

    await #expect(
      throws: IPCCommandError.invalidRequest("window disappeared during Space movement: 42")
    ) {
      try await transfer.move(windowID: 42, to: .next, isValidWindow: { valid })
    }
  }

  @Test("move: refuses overlapping moves for the same window")
  func overlappingMoves() async throws {
    var membership: [UInt64] = [11]
    var transfer: WindowSpaceTransfer!

    transfer = WindowSpaceTransfer(
      spaceProvider: { spaces },
      membershipProvider: { _ in membership },
      submitMove: { _, _ in },
      wait: {
        await #expect(
          throws: IPCCommandError.invalidRequest("window is already moving to another Space: 42")
        ) {
          try await transfer.move(windowID: 42, to: .previous)
        }

        membership = [33]
      }
    )

    try await transfer.move(windowID: 42, to: .next)
  }

  @Test("move: cancellation releases the window for subsequent requests")
  func cancellation() async throws {
    var cancelledWait = false
    var membership: [UInt64] = [11]

    let transfer = WindowSpaceTransfer(
      spaceProvider: { spaces },
      membershipProvider: { _ in membership },
      submitMove: { _, _ in },
      wait: {
        if !cancelledWait {
          cancelledWait = true
          throw CancellationError()
        }

        membership = [33]
      }
    )

    await #expect(throws: CancellationError.self) {
      try await transfer.move(windowID: 42, to: .next)
    }

    try await transfer.move(windowID: 42, to: .next)
  }

  private var spaces: [Space] {
    [Space(id: 11, type: .normal), Space(id: 22, type: .fullscreen), Space(id: 33, type: .normal)]
  }
}
