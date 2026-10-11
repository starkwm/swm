import AppKit
import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("WindowFrameReconciler")
struct WindowFrameReconcilerTests {
  @Test(
    "nextAnimationDeadline: frame work does not shift the next deadline",
    arguments: [0, 5, 15]
  )
  func nextAnimationDeadlineFrameWorkDoesNotShiftTheNextDeadline(workMilliseconds: Int) {
    let start = ContinuousClock.now
    let interval = Duration.seconds(1.0 / 60)
    let previous = start.advanced(by: interval)
    let deadline = WindowFrameReconciler.nextAnimationDeadline(
      after: previous,
      now: previous.advanced(by: .milliseconds(workMilliseconds))
    )

    #expect(deadline == previous.advanced(by: interval))
  }

  @Test("nextAnimationDeadline: slow frames skip missed deadlines without shifting the cadence")
  func nextAnimationDeadlineSlowFramesSkipMissedDeadlinesWithoutShiftingTheCadence() {
    let previous = ContinuousClock.now
    let interval = Duration.seconds(1.0 / 60)
    let deadline = WindowFrameReconciler.nextAnimationDeadline(
      after: previous,
      now: previous.advanced(by: .milliseconds(40))
    )

    #expect(deadline == previous.advanced(by: interval * 3))
  }

  @Test("animationDuration: disabling finishes the pending destination")
  func animationDurationDisablingFinishesThePendingDestination() {
    var frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in frame },
      frameMutation: { _, target, _ in
        frame = target
        return .success
      },
      reduceMotion: { false }
    )
    reconciler.animationDuration = 1
    let target = CGRect(x: 300, y: 100, width: 200, height: 200)
    reconciler.apply([1: target])
    reconciler.animationDuration = 0
    #expect(frame == target)
    reconciler.advanceAnimations(at: .now.advanced(by: .seconds(2)))
    #expect(frame == target)
  }

  @Test("apply: easing changes affect new animations, not active ones")
  func applyEasingChangesAffectNewAnimationsNotActiveOnes() {
    var frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in frame },
      frameMutation: { _, target, _ in
        frame = target
        return .success
      },
      reduceMotion: { false }
    )
    reconciler.animationDuration = 1
    reconciler.animationEasing = .linear
    let start = ContinuousClock.now
    reconciler.apply([1: frame.offsetBy(dx: 100, dy: 0)], at: start)
    reconciler.animationEasing = .easeOutCubic
    let halfway = start.advanced(by: .milliseconds(500))
    reconciler.advanceAnimations(at: halfway)
    #expect(frame.minX == 50)
    reconciler.apply([1: frame.offsetBy(dx: 100, dy: 0)], at: halfway)
    reconciler.advanceAnimations(at: halfway.advanced(by: .milliseconds(500)))
    #expect(frame.minX == 137.5)
    reconciler.cancelAnimations()
  }

  @Test("apply: scheduler does not retain the reconciler")
  func applySchedulerDoesNotRetainTheReconciler() {
    var reconciler: WindowFrameReconciler? = WindowFrameReconciler(
      currentFrame: { _ in .zero },
      frameMutation: { _, _, _ in .success },
      reduceMotion: { false }
    )
    weak var reference = reconciler
    reconciler?.animationDuration = 1
    reconciler?.apply([1: CGRect(x: 100, y: 0, width: 100, height: 100)])
    reconciler = nil
    #expect(reference == nil)
  }

  @Test("apply: retargets from the current frame and suppresses intermediate feedback")
  func applyRetargetsFromTheCurrentFrameAndSuppressesIntermediateFeedback() {
    var frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in frame },
      frameMutation: { _, target, _ in
        frame = target
        return .success
      },
      reduceMotion: { false }
    )
    reconciler.animationDuration = 1
    let start = ContinuousClock.now
    reconciler.apply([1: CGRect(x: 100, y: 0, width: 100, height: 100)], at: start)
    let halfway = start.advanced(by: .milliseconds(500))
    reconciler.advanceAnimations(at: halfway)
    #expect(frame.minX == 75)
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: frame))

    let intermediate = frame
    let destination = CGRect(x: -100, y: 0, width: 200, height: 100)
    reconciler.apply([1: destination], at: halfway)
    #expect(frame == intermediate)
    #expect(reconciler.frames(for: [1])[1] == destination)
    reconciler.advanceAnimations(at: halfway.advanced(by: .seconds(1)))
    #expect(frame == destination)
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: frame))
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: frame))
    reconciler.animationDuration = 0
  }

  @Test("apply: Reduce Motion applies frames immediately")
  func applyReduceMotionAppliesFramesImmediately() {
    var frame = CGRect.zero
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in frame },
      frameMutation: { _, target, _ in
        frame = target
        return .success
      },
      reduceMotion: { true }
    )
    reconciler.animationDuration = 1
    let target = CGRect(x: 300, y: 100, width: 200, height: 200)
    reconciler.apply([1: target])
    #expect(frame == target)
  }

  @Test("apply: skips matching frames within tolerance")
  func applySkipsMatchingFramesWithinTolerance() {
    var mutationCount = 0
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in CGRect(x: 0.5, y: 0, width: 100, height: 100) },
      frameMutation: { _, _, _ in
        mutationCount += 1
        return .success
      }
    )

    reconciler.apply([1: CGRect(x: 0, y: 0, width: 100, height: 100)])

    #expect(mutationCount == 0)
  }

  @Test("apply: registers the entire batch before the first mutation")
  func applyRegistersTheEntireBatchBeforeTheFirstMutation() throws {
    var reconciler: WindowFrameReconciler!
    reconciler = WindowFrameReconciler(
      currentFrame: { _ in .zero },
      frameMutation: { windowID, _, _ in
        #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: .zero))
        #expect(reconciler.shouldSuppressNotification(for: 2, actualFrame: .zero))
        #expect([CGWindowID(1), 2].contains(windowID))
        return .success
      }
    )

    reconciler.apply([
      1: CGRect(x: 0, y: 0, width: 100, height: 100),
      2: CGRect(x: 100, y: 0, width: 100, height: 100),
    ])
  }

  @Test("apply: reports failures and bounds their feedback suppression")
  func applyReportsFailuresAndBoundsTheirFeedbackSuppression() {
    let reconciler = WindowFrameReconciler(
      currentFrame: { windowID in windowID == 1 ? .zero : nil },
      frameMutation: { _, _, _ in .resizeFailed }
    )

    reconciler.apply([
      1: CGRect(x: 0, y: 0, width: 100, height: 100),
      2: CGRect(x: 100, y: 0, width: 100, height: 100),
    ])

    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: .zero))
    #expect(reconciler.shouldSuppressNotification(for: 2, actualFrame: .zero) == false)
  }

  @Test("apply: retries a successful mutation that did not reach its target")
  func applyRetriesASuccessfulMutationThatDidNotReachItsTarget() {
    let initialFrame = CGRect(x: 750, y: 400, width: 250, height: 400)
    let targetFrame = CGRect(x: 500, y: 400, width: 500, height: 400)
    var frame = initialFrame
    var mutationCount = 0
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in frame },
      frameMutation: { _, targetFrame, currentFrame in
        mutationCount += 1
        if mutationCount == 1 {
          frame = CGRect(origin: targetFrame.origin, size: currentFrame.size)
        } else {
          frame = targetFrame
        }
        return .success
      }
    )

    reconciler.apply([1: targetFrame])

    #expect(mutationCount == 2)
    #expect(frame == targetFrame)
  }

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

  @Test("cancelAnimations: cancellation preserves a newer frame and other animations")
  func cancelAnimationsCancellationPreservesANewerFrameAndOtherAnimations() {
    var frames = [CGWindowID(1): CGRect.zero, 2: CGRect.zero]
    let reconciler = WindowFrameReconciler(
      currentFrame: { frames[$0] },
      frameMutation: { id, target, _ in
        frames[id] = target
        return .success
      },
      reduceMotion: { false }
    )
    reconciler.animationDuration = 1
    let start = ContinuousClock.now
    let target = CGRect(x: 100, y: 0, width: 100, height: 100)
    reconciler.apply([1: target, 2: target], at: start)
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(500)))
    reconciler.cancelAnimations(for: [1])
    let newerFrame = CGRect(x: 300, y: 0, width: 200, height: 100)
    frames[1] = newerFrame
    reconciler.advanceAnimations(at: start.advanced(by: .seconds(1)))
    #expect(frames[1] == newerFrame)
    #expect(frames[2] == target)
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: newerFrame))
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

  @Test("advanceAnimations: intermediate ticks read each window once and feedback does not read it")
  func advanceAnimationsIntermediateTicksReadEachWindowOnceAndFeedbackDoesNotReadIt() {
    var frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    var frameReads = 0
    var mutations = 0
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in
        frameReads += 1
        return frame
      },
      frameMutation: { _, target, current in
        #expect(current == frame)
        mutations += 1
        frame = target
        return .success
      },
      reduceMotion: { false }
    )
    reconciler.animationDuration = 1
    let start = ContinuousClock.now
    reconciler.apply([1: CGRect(x: 100, y: 0, width: 200, height: 100)], at: start)
    frameReads = 0

    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(500)))
    #expect(frame.minX == 75)
    #expect(frame.width == 175)
    #expect(mutations == 1)
    #expect(frameReads == 1)

    #expect(reconciler.shouldSuppressNotification(for: 1))
    #expect(reconciler.shouldSuppressNotification(for: 1))
    #expect(frameReads == 1)

    reconciler.advanceAnimations(at: start.advanced(by: .seconds(1)))
    #expect(frameReads == 3)
    #expect(reconciler.shouldSuppressNotification(for: 1))
    #expect(frameReads == 4)
    #expect(reconciler.shouldSuppressNotification(for: 1))
    #expect(frameReads == 5)
  }

  @Test("advanceAnimations: clamped frames are retried at the destination")
  func advanceAnimationsClampedFramesAreRetriedAtTheDestination() {
    var frame = CGRect(x: 750, y: 400, width: 250, height: 400)
    var lastTarget: CGRect?
    var mutations = 0
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in frame },
      frameMutation: { _, target, current in
        mutations += 1
        // Model an app that accepts the larger size only after moving to the new origin.
        frame = lastTarget == target ? target : CGRect(origin: target.origin, size: current.size)
        lastTarget = target
        return .success
      },
      reduceMotion: { false }
    )
    reconciler.animationDuration = 1
    let start = ContinuousClock.now
    let target = CGRect(x: 500, y: 400, width: 500, height: 400)
    reconciler.apply([1: target], at: start)

    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(500)))
    #expect(mutations == 1)
    #expect(frame.origin != target.origin)

    reconciler.advanceAnimations(at: start.advanced(by: .seconds(1)))
    #expect(mutations == 3)
    #expect(frame == target)
  }

  @Test("advanceAnimations: a vanished window is removed without another read or mutation")
  func advanceAnimationsAVanishedWindowIsRemovedWithoutAnotherReadOrMutation() {
    var frame: CGRect? = CGRect(x: 0, y: 0, width: 100, height: 100)
    var frameReads = 0
    var mutations = 0
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in
        frameReads += 1
        return frame
      },
      frameMutation: { _, _, _ in
        mutations += 1
        return .success
      },
      reduceMotion: { false }
    )
    reconciler.animationDuration = 1
    let start = ContinuousClock.now
    reconciler.apply([1: CGRect(x: 100, y: 0, width: 200, height: 100)], at: start)
    frame = nil
    frameReads = 0

    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(500)))
    reconciler.advanceAnimations(at: start.advanced(by: .seconds(1)))
    #expect(frameReads == 1)
    #expect(mutations == 0)
    #expect(!reconciler.shouldSuppressNotification(for: 1))
    #expect(frameReads == 1)
  }

  @Test("advanceAnimations: final tick applies a destination within one point")
  func advanceAnimationsFinalTickAppliesADestinationWithinOnePoint() {
    var frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in frame },
      frameMutation: { _, target, _ in
        frame = target
        return .success
      },
      reduceMotion: { false }
    )
    reconciler.animationDuration = 1
    let start = ContinuousClock.now
    let target = CGRect(x: 100, y: 0, width: 100, height: 100)
    reconciler.apply([1: target], at: start)
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(950)))
    #expect(frame.minX == 99.75)
    reconciler.advanceAnimations(at: start.advanced(by: .seconds(1)))
    #expect(frame == target)
  }

  @Test("shouldSuppressNotification: holds intermediate and duplicate destination events")
  func shouldSuppressNotificationHoldsIntermediateAndDuplicateDestinationEvents() {
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in .zero },
      frameMutation: { _, _, _ in .success }
    )
    let target = CGRect(x: 100, y: 100, width: 400, height: 300)
    reconciler.apply([1: target])

    #expect(
      reconciler.shouldSuppressNotification(
        for: 1,
        actualFrame: CGRect(x: 0, y: 0, width: 400, height: 300)
      )
    )
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: .zero))
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: target))
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: target))
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: .zero))
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: target))
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
