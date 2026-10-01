import StarkSkyLight
import Testing

@testable import SwmLib

@Suite("SpaceActivation")
@MainActor
struct SpaceActivationTests {
  @Test("activate: confirms the target display without requiring keyboard focus")
  func confirmation() async throws {
    var observed = snapshot(focused: 55)
    var waits = 0
    let activation = SpaceActivation(
      snapshotProvider: { observed },
      submitActivation: { spaceID, displayID, hiddenIDs in
        #expect(spaceID == 33)
        #expect(displayID == "Main")
        #expect(hiddenIDs == [11])
      },
      wait: {
        waits += 1
        observed = snapshot(current: waits == 1 ? nil : 33, focused: 55)
      }
    )

    let result = try await activation.activate(index: 1)

    #expect(waits == 2)
    #expect(result.displays[0].currentSpaceID?.rawValue == 33)
    #expect(result.displays[1].currentSpaceID?.rawValue == 55)
    #expect(result.activeSpaceID?.rawValue == 55)
  }

  @Test("activate: targeting a visible Desktop does not submit a write")
  func visibleDesktop() async throws {
    let before = snapshot()
    let activation = SpaceActivation(
      snapshotProvider: { before },
      submitActivation: { _, _, _ in Issue.record("unexpected submission") },
      wait: { Issue.record("unexpected wait") }
    )

    #expect(try await activation.activate(index: 0) == before)
  }

  @Test("activate: rejects out-of-range indexes", arguments: [-1, 4, Int.max])
  func invalidIndex(index: Int) async {
    let activation = SpaceActivation(
      snapshotProvider: { snapshot() },
      submitActivation: { _, _, _ in Issue.record("unexpected submission") }
    )

    await #expect(throws: IPCCommandError.invalidRequest("space index out of range: \(index)")) {
      try await activation.activate(index: index)
    }
  }

  @Test("activate: refuses fullscreen or unknown Spaces on the target display")
  func unsupportedLayouts() async {
    for type: StarkSkyLight.SpaceType in [.fullscreen, .unknown(3)] {
      let activation = SpaceActivation(
        snapshotProvider: { snapshot(targetType: type) },
        submitActivation: { _, _, _ in Issue.record("unexpected submission") }
      )

      for index in [0, 1] {
        await #expect(
          throws: IPCCommandError.invalidRequest(
            "Space activation requires a display containing only normal desktop Spaces"
          )
        ) {
          try await activation.activate(index: index)
        }
      }
    }
  }

  @Test("activate: refuses incomplete topology before submission")
  func incompleteTopology() async {
    let activation = SpaceActivation(
      snapshotProvider: { snapshot(current: nil) },
      submitActivation: { _, _, _ in Issue.record("unexpected submission") }
    )

    await #expect(
      throws: IPCCommandError.internalError(
        "Space topology is incomplete; try again after the transition"
      )
    ) {
      try await activation.activate(index: 1)
    }
  }

  @Test("activate: a submitted but unchanged current Space times out")
  func timeout() async {
    var waits = 0
    let activation = SpaceActivation(
      snapshotProvider: { snapshot() },
      submitActivation: { _, _, _ in },
      wait: { waits += 1 }
    )

    await #expect(
      throws: IPCCommandError.internalError(
        "timed out activating Space 33; activation was requested but not confirmed"
      )
    ) {
      try await activation.activate(index: 1)
    }
    #expect(waits == 40)
  }

  @Test("activate: accepts confirmation on the last poll")
  func finalPoll() async throws {
    var waits = 0
    let activation = SpaceActivation(
      snapshotProvider: { snapshot(current: waits == 40 ? 33 : 11) },
      submitActivation: { _, _, _ in },
      wait: { waits += 1 }
    )

    let result = try await activation.activate(index: 1)
    #expect(waits == 40)
    #expect(result.displays[0].currentSpaceID?.rawValue == 33)
  }

  @Test(
    "activate: detects removal of the target or its display after submission",
    arguments: [false, true]
  )
  func disappearance(removeDisplay: Bool) async {
    var observed = snapshot()
    let activation = SpaceActivation(
      snapshotProvider: { observed },
      submitActivation: { _, _, _ in
        observed = SpaceSnapshot(
          displays: removeDisplay
            ? []
            : [
              DisplaySpaces(
                id: DisplayID(rawValue: "Main"),
                spaces: [StarkSkyLight.Space(id: SpaceID(rawValue: 11), type: .desktop)],
                currentSpaceID: SpaceID(rawValue: 11)
              )
            ],
          activeSpaceID: nil
        )
      }
    )

    await #expect(
      throws: IPCCommandError.internalError(
        "Space activation was requested, but the target Space or display disappeared"
      )
    ) {
      try await activation.activate(index: 1)
    }
  }

  @Test("activate: a failed query reports that activation was already requested")
  func queryFailure() async {
    var submitted = false
    let activation = SpaceActivation(
      snapshotProvider: {
        if submitted { throw SkyLightError.queryFailed("SLSCopyManagedDisplaySpaces") }
        return snapshot()
      },
      submitActivation: { _, _, _ in submitted = true }
    )

    do {
      _ = try await activation.activate(index: 1)
      Issue.record("expected confirmation query failure")
    } catch let error as IPCCommandError {
      #expect(error.errorCode == .internalError)
      #expect(error.message.contains("activation was requested"))
      #expect(error.message.contains("SLSCopyManagedDisplaySpaces"))
    } catch {
      Issue.record("unexpected error: \(error)")
    }
  }

  @Test("activate: an unavailable bridge does not wait for confirmation")
  func unavailableBridge() async {
    let activation = SpaceActivation(
      snapshotProvider: { snapshot() },
      submitActivation: { _, _, _ in throw SpaceActivationBridgeError.unavailable },
      wait: { Issue.record("unexpected wait") }
    )

    await #expect(throws: SpaceActivationBridgeError.unavailable) {
      try await activation.activate(index: 1)
    }
  }

  @Test("activate: prevents overlapping writes on one display but permits another display")
  func overlappingRequests() async throws {
    var observed = snapshot()
    var activation: SpaceActivation!
    activation = SpaceActivation(
      snapshotProvider: { observed },
      submitActivation: { spaceID, _, _ in
        if spaceID == 66 {
          observed = snapshot(otherCurrent: 66)
        }
      },
      wait: {
        await #expect(
          throws: IPCCommandError.invalidRequest(
            "Space activation is already in progress on this display"
          )
        ) {
          try await activation.activate(index: 0)
        }
        let otherResult = try await activation.activate(index: 3)
        #expect(otherResult.displays[1].currentSpaceID?.rawValue == 66)
        observed = snapshot(current: 33, otherCurrent: 66)
      }
    )

    _ = try await activation.activate(index: 1)
  }

  @Test("activate: cancellation releases the display for a subsequent request")
  func cancellation() async throws {
    var observed = snapshot()
    var cancelled = false
    let activation = SpaceActivation(
      snapshotProvider: { observed },
      submitActivation: { _, _, _ in },
      wait: {
        if !cancelled {
          cancelled = true
          throw CancellationError()
        }
        observed = snapshot(current: 33)
      }
    )

    await #expect(throws: CancellationError.self) {
      try await activation.activate(index: 1)
    }
    _ = try await activation.activate(index: 1)
  }

  private func snapshot(
    current: UInt64? = 11,
    focused: UInt64? = 11,
    otherCurrent: UInt64 = 55,
    targetType: StarkSkyLight.SpaceType = .desktop
  ) -> SpaceSnapshot {
    SpaceSnapshot(
      displays: [
        DisplaySpaces(
          id: DisplayID(rawValue: "Main"),
          spaces: [
            StarkSkyLight.Space(id: SpaceID(rawValue: 11), type: .desktop),
            StarkSkyLight.Space(id: SpaceID(rawValue: 33), type: targetType),
          ],
          currentSpaceID: current.map { SpaceID(rawValue: $0) }
        ),
        DisplaySpaces(
          id: DisplayID(rawValue: "other-display"),
          spaces: [
            StarkSkyLight.Space(id: SpaceID(rawValue: 55), type: .desktop),
            StarkSkyLight.Space(id: SpaceID(rawValue: 66), type: .desktop),
          ],
          currentSpaceID: SpaceID(rawValue: otherCurrent)
        ),
      ],
      activeSpaceID: focused.map { SpaceID(rawValue: $0) }
    )
  }
}
