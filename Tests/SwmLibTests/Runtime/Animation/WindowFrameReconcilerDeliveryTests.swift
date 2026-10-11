import AppKit
import Testing

@testable import SwmLib

extension WindowFrameReconcilerTests {
  @Test("apply: retargets from completed writes and retains pending destinations")
  func applyRetargetsFromCompletedWritesAndRetainsPendingDestinations() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeDeliveryReconciler(app)
    reconciler.animationDuration = 1
    reconciler.animationEasing = .linear
    let start = ContinuousClock.now.advanced(by: .seconds(10))
    reconciler.apply([1: animationFrame(100)], at: start)
    #expect(reconciler.frames(for: [1])[1] == animationFrame(100))
    try await waitForAnimation { reconciler.isAnimating(1) }
    app.blockNextWrite()
    defer { app.release() }
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(500)))
    try await waitForAnimation { app.writeCount == 1 }
    reconciler.apply([1: animationFrame(200)], at: start)
    #expect(reconciler.frames(for: [1])[1] == animationFrame(200))
    app.frame = animationFrame(25)
    app.release()
    try await waitForAnimation { reconciler.isAnimating(1) && app.readCount == 2 }
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(500)))
    // The started AX operation lands at 50 after cancellation. Retarget from that
    // actual result, not the frame observed while the old operation was blocked.
    try await waitForAnimation { app.frame == animationFrame(125) }
    reconciler.advanceAnimations(at: start.advanced(by: .seconds(1)))
    try await waitForAnimation { reconciler.isIdle }
    #expect(app.frame == animationFrame(200))
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: animationFrame(200)))
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: animationFrame(300)))
  }

  @Test(
    "apply: settles final writes after scheduling stops",
    arguments: [0, 1, 2]
  )
  func applySettlesFinalWritesAfterSchedulingStops(mode: Int) async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeDeliveryReconciler(app, reduceMotion: { mode == 2 })
    reconciler.animationDuration = 1
    let start = ContinuousClock.now
    reconciler.apply([1: animationFrame(100)], at: start)
    if mode != 2 {
      try await waitForAnimation { reconciler.isAnimating(1) }
      if mode == 0 {
        reconciler.animationDuration = 0
      } else {
        reconciler.advanceAnimations(at: start.advanced(by: .seconds(2)))
      }
    }
    try await waitForAnimation { reconciler.isIdle }
    #expect(app.frame == animationFrame(100))
  }

  @Test("apply: stops terminal failures and suppresses delayed feedback")
  func applyStopsTerminalFailuresAndSuppressesDelayedFeedback() async throws {
    let app = AnimationTestApp(processID: 1)
    app.clampWrites = true
    var failures = [CGWindowID]()
    let reconciler = makeDeliveryReconciler(app, terminalFailure: { failures.append($0) })
    reconciler.apply([1: animationFrame(100)])
    try await waitForAnimation { reconciler.isIdle }
    #expect(failures == [1])
    #expect(app.writeCount == 2)
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: app.frame))
  }

  @Test("apply: preserves a pending final write for repeated targets")
  func applyPreservesAPendingFinalWriteForRepeatedTargets() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeDeliveryReconciler(app)
    app.blockNextWrite()
    defer { app.release() }
    reconciler.apply([1: animationFrame(100)])
    try await waitForAnimation { app.writeCount == 1 }
    for _ in 0..<10 { reconciler.apply([1: animationFrame(100)]) }
    app.release()
    try await waitForAnimation { reconciler.isIdle }
    #expect(app.frame == animationFrame(100))
    #expect(app.writeCount == 1)
  }

  @Test("prepareForSynchronousMutation: waits for cancelled writes and UI restoration")
  func prepareForSynchronousMutationWaitsForCancelledWritesAndUIRestoration() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeDeliveryReconciler(app)
    app.blockNextWrite()
    defer { app.release() }
    reconciler.apply([1: animationFrame(100)])
    try await waitForAnimation { app.writeCount == 1 }
    Task.detached { app.release() }
    reconciler.prepareForSynchronousMutation(for: 1)
    #expect(app.frame == animationFrame(100))
    #expect(app.beginCount == app.endCount)
    // Model the subsequent synchronous command, after the old AX call has settled.
    app.frame = animationFrame(200)
    #expect(reconciler.isIdle)
    await Task.yield()
    #expect(app.frame == animationFrame(200))
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: app.frame))
  }

  @Test("retainWindows/beginInteraction: cancels pending reads and prevents restart")
  func retainWindowsBeginInteractionCancelsPendingReadsAndPreventsRestart() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeDeliveryReconciler(app)
    reconciler.animationDuration = 1
    reconciler.apply([1: animationFrame(100)])
    reconciler.beginInteraction(for: 1)
    reconciler.apply([1: animationFrame(200)])
    #expect(reconciler.isIdle)
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: animationFrame(20)))
    reconciler.endInteractions()
    reconciler.apply([1: animationFrame(300)])
    reconciler.retainWindows([])
    try await Task.sleep(for: .milliseconds(20))
    #expect(reconciler.isIdle)
    #expect(app.writeCount == 0)
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: animationFrame(20)))
  }

  @Test("pointerDragged/endInteractions: suspends writes and reconciles once after a drag")
  func pointerDraggedEndInteractionsSuspendsWritesAndReconcilesOnceAfterADrag() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeDeliveryReconciler(app)
    var ended = 0
    reconciler.onInteractionEnded = { ended += 1 }
    reconciler.animationDuration = 1
    reconciler.apply([1: animationFrame(100)])
    try await waitForAnimation { reconciler.isAnimating(1) }
    reconciler.pointerDown(on: 1)
    reconciler.endInteractions()
    #expect(reconciler.isAnimating(1))
    #expect(ended == 0)
    reconciler.pointerDown(on: 1)
    reconciler.pointerDragged()
    reconciler.pointerDragged()
    #expect(reconciler.isIdle)
    reconciler.apply([1: animationFrame(200)])
    #expect(reconciler.isIdle)
    reconciler.endInteractions()
    reconciler.endInteractions()
    #expect(ended == 1)
  }
}
