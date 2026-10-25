import AppKit
import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("WindowFrameReconciler")
struct WindowFrameReconcilerTests {
  @Test(
    "nextAnimationDeadline: preserves cadence and skips missed intervals",
    arguments: [(0, 1), (5, 1), (15, 1), (40, 3)]
  )
  func nextAnimationDeadlinePreservesCadenceAndSkipsMissedIntervals(
    workMilliseconds: Int,
    intervals: Int
  ) {
    let previous = ContinuousClock.now
    let interval = Duration.seconds(1.0 / 60)
    let deadline = WindowFrameReconciler.nextAnimationDeadline(
      after: previous,
      now: previous.advanced(by: .milliseconds(workMilliseconds))
    )
    #expect(deadline == previous.advanced(by: interval * intervals))
  }

  @Test("apply: easing changes affect new animations, not active ones")
  func applyEasingChangesAffectNewAnimationsNotActiveOnes() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeTestReconciler(app)
    reconciler.animationDuration = 1
    reconciler.animationEasing = .linear
    // Start in the future so the asynchronous initial read does not shift the timeline.
    let start = ContinuousClock.now.advanced(by: .seconds(10))
    reconciler.apply([1: animationFrame(100)], at: start)
    try await waitForAnimation { reconciler.isAnimating(1) }
    reconciler.animationEasing = .easeOutCubic
    let halfway = start.advanced(by: .milliseconds(500))
    reconciler.advanceAnimations(at: halfway)
    try await waitForAnimation { app.frame == animationFrame(50) }
    reconciler.apply([1: animationFrame(150)], at: halfway)
    try await waitForAnimation { reconciler.isAnimating(1) }
    reconciler.advanceAnimations(at: halfway.advanced(by: .milliseconds(500)))
    try await waitForAnimation { app.frame == animationFrame(137.5) }
    reconciler.cancelAnimations()
  }

  @Test("apply: scheduler does not retain the reconciler")
  func applySchedulerDoesNotRetainTheReconciler() async throws {
    let app = AnimationTestApp(processID: 1)
    var reconciler: WindowFrameReconciler? = makeTestReconciler(app, automaticallySchedule: true)
    weak var reference = reconciler
    reconciler?.animationDuration = 1
    reconciler?.apply([1: animationFrame(100)])
    try await waitForAnimation { reconciler?.isAnimating(1) == true }
    reconciler = nil
    #expect(reference == nil)
  }

  @Test("apply: retargets from completed writes and retains pending destinations")
  func applyRetargetsFromCompletedWritesAndRetainsPendingDestinations() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeTestReconciler(app)
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
    let reconciler = makeTestReconciler(app, reduceMotion: { mode == 2 })
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
    let reconciler = makeTestReconciler(app, terminalFailure: { failures.append($0) })
    reconciler.apply([1: animationFrame(100)])
    try await waitForAnimation { reconciler.isIdle }
    #expect(failures == [1])
    #expect(app.writeCount == 2)
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: app.frame))
  }

  @Test("apply: preserves a pending final write for repeated targets")
  func applyPreservesAPendingFinalWriteForRepeatedTargets() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeTestReconciler(app)
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

  @Test("cancelAnimations: cancellation preserves a newer frame and other animations")
  func cancelAnimationsCancellationPreservesANewerFrameAndOtherAnimations() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeTestReconciler(app)
    reconciler.animationDuration = 1
    reconciler.animationEasing = .linear
    let start = ContinuousClock.now.advanced(by: .seconds(10))
    let target = animationFrame(100)
    reconciler.apply([1: target, 2: target], at: start)
    try await waitForAnimation { reconciler.isAnimating(1) && reconciler.isAnimating(2) }
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(500)))
    try await waitForAnimation {
      app.frame(for: 1) == animationFrame(50) && app.frame(for: 2) == animationFrame(50)
    }
    reconciler.cancelAnimations(for: [1])
    let newerFrame = CGRect(x: 300, y: 0, width: 200, height: 100)
    app.setFrame(newerFrame, for: 1)
    reconciler.advanceAnimations(at: start.advanced(by: .seconds(1)))
    try await waitForAnimation { reconciler.isIdle }
    #expect(app.frame(for: 1) == newerFrame)
    #expect(app.frame(for: 2) == target)
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: newerFrame))
  }

  @Test("prepareForSynchronousMutation: waits for cancelled writes and UI restoration")
  func prepareForSynchronousMutationWaitsForCancelledWritesAndUIRestoration() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeTestReconciler(app)
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
  func retainWindowsBeginInteractionCancelsPendingReadsAndPreventsRestart() async {
    let app = AnimationTestApp(processID: 1)
    let delivery = AnimationFrameDelivery { _ in app.backend }
    let reconciler = makeTestReconciler(app, delivery: delivery)
    reconciler.animationDuration = 1
    reconciler.apply([1: animationFrame(100)])
    reconciler.beginInteraction(for: 1)
    reconciler.apply([1: animationFrame(200)])
    #expect(reconciler.isIdle)
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: animationFrame(20)))
    reconciler.endInteractions()
    reconciler.apply([1: animationFrame(300)])
    reconciler.retainWindows([])
    // Drain cancelled backend work before checking for writes, without a timed delay.
    delivery.waitForPendingOperations(for: 1)
    await Task.yield()
    #expect(reconciler.isIdle)
    #expect(app.writeCount == 0)
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: animationFrame(20)))
  }

  @Test("advanceAnimations: finishes only stalled display windows during long animations")
  func advanceAnimationsFinishesOnlyStalledDisplayWindowsDuringLongAnimations() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeTestReconciler(app)
    reconciler.animationDuration = 10
    reconciler.apply([1: animationFrame(100), 2: animationFrame(200)])
    try await waitForAnimation { reconciler.isAnimating(1) && reconciler.isAnimating(2) }
    reconciler.advanceAnimations(windowIDs: [1], finishImmediately: true)
    try await waitForAnimation { app.frame(for: 1) == animationFrame(100) }
    #expect(!reconciler.isAnimating(1))
    #expect(reconciler.isAnimating(2))
    #expect(app.frame(for: 2) == animationFrame(0))
    reconciler.cancelAnimations(for: [2])
    try await waitForAnimation { reconciler.isIdle }
  }

  @Test("apply: a vanished window stops without writes")
  func applyAVanishedWindowStopsWithoutWrites() async throws {
    let app = AnimationTestApp(processID: 1)
    var failures = [CGWindowID]()
    let reconciler = makeTestReconciler(
      app,
      delivery: AnimationFrameDelivery { _ in nil },
      terminalFailure: { failures.append($0) }
    )
    reconciler.animationDuration = 1
    reconciler.apply([1: animationFrame(100)])
    try await waitForAnimation { reconciler.isIdle }
    #expect(failures == [1])
    #expect(!reconciler.isAnimating(1))
    #expect(app.writeCount == 0)
  }

  @Test("pointerDragged/endInteractions: suspends writes and reconciles once after a drag")
  func pointerDraggedEndInteractionsSuspendsWritesAndReconcilesOnceAfterADrag() async throws {
    let app = AnimationTestApp(processID: 1)
    let reconciler = makeTestReconciler(app)
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
