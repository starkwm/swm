import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("WindowFrameReconciler")
struct WindowFrameReconcilerTests {
  @Test("animation: frame work does not shift the next deadline", arguments: [0, 5, 15])
  func frameWorkDoesNotShiftDeadline(workMilliseconds: Int) {
    let start = ContinuousClock.now
    let interval = Duration.seconds(1.0 / 60)
    let previous = start.advanced(by: interval)
    let deadline = WindowFrameReconciler.nextAnimationDeadline(
      after: previous,
      now: previous.advanced(by: .milliseconds(workMilliseconds))
    )

    #expect(deadline == previous.advanced(by: interval))
  }

  @Test("animation: slow frames skip missed deadlines without shifting the cadence")
  func slowFramesSkipMissedDeadlines() {
    let previous = ContinuousClock.now
    let interval = Duration.seconds(1.0 / 60)
    let deadline = WindowFrameReconciler.nextAnimationDeadline(
      after: previous,
      now: previous.advanced(by: .milliseconds(40))
    )

    #expect(deadline == previous.advanced(by: interval * 3))
  }

  @Test("animation: intermediate ticks read each window once and feedback does not read it")
  func intermediateTicksAvoidRedundantFrameReads() {
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
    #expect(!reconciler.shouldSuppressNotification(for: 1))
    #expect(frameReads == 4)
  }

  @Test("animation: clamped frames are retried at the destination")
  func clampedFramesAreRetriedAtDestination() {
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

  @Test("animation: a vanished window is removed without another read or mutation")
  func vanishedWindowStopsAnimating() {
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

  @Test("direct commands: one-point moves are not skipped")
  func directCommandAppliesSmallMove() {
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
    let target = frame.offsetBy(dx: 1, dy: 0)
    #expect(makeTiling(frameReconciler: reconciler).animateFrame(target, for: 1))
    reconciler.advanceAnimations(at: .now.advanced(by: .seconds(2)))
    #expect(frame == target)
  }

  @Test(
    "direct commands: disabled animation and Reduce Motion use the synchronous fallback",
    arguments: [false, true]
  )
  func directCommandsUseSynchronousFallback(reduceMotion: Bool) {
    var mutations = 0
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in .zero },
      frameMutation: { _, _, _ in
        mutations += 1
        return .success
      },
      reduceMotion: { reduceMotion }
    )
    reconciler.animationDuration = reduceMotion ? 1 : 0
    let tiling = makeTiling(frameReconciler: reconciler)
    #expect(!tiling.animateFrame(CGRect(x: 100, y: 0, width: 100, height: 100), for: 1))
    reconciler.advanceAnimations(at: .now.advanced(by: .seconds(2)))
    #expect(mutations == 0)
  }

  @Test("animation: final tick applies a destination within one point")
  func finalTickAppliesExactDestination() {
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

  @Test("animation: cancellation preserves a newer frame and other animations")
  func cancellationPreservesNewerFrame() {
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

  @Test(
    "animation: tiling changes discard old destinations",
    arguments: ["window-float", "space-float", "all-float", "membership", "direct-command"]
  )
  func tilingChangesCancelAnimations(change: String) {
    var frame = CGRect.zero
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10]]
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in frame },
      frameMutation: { _, target, _ in
        frame = target
        return .success
      },
      reduceMotion: { false }
    )
    let tiling = makeTiling(
      windows: { [window(id: 1)] },
      memberships: { memberships },
      frameReconciler: reconciler
    )
    tiling.initialize()
    reconciler.animationDuration = 1
    let start = ContinuousClock.now
    reconciler.apply([1: CGRect(x: 100, y: 0, width: 100, height: 100)], at: start)
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(500)))

    switch change {
    case "window-float": #expect(tiling.setWindowLayout(.float, for: 1))
    case "space-float": #expect(tiling.setLayout(.float, for: 10))
    case "all-float": tiling.setLayoutForSpaces(.float)
    case "membership":
      memberships = [1: [11]]
      tiling.reconcileAndReflowVisibleSpaces()
    default: tiling.cancelAnimation(for: 1)
    }
    let stoppedFrame = frame
    reconciler.advanceAnimations(at: start.advanced(by: .seconds(1)))
    #expect(frame == stoppedFrame)
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: frame))
  }

  @Test("animation: retargets from the current frame and suppresses intermediate feedback")
  func animationRetargets() {
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
    #expect(!reconciler.shouldSuppressNotification(for: 1, actualFrame: frame))
    reconciler.animationDuration = 0
  }

  @Test("animation: disabling finishes the pending destination")
  func disablingAnimationFinishes() {
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

  @Test("animation: Reduce Motion applies frames immediately")
  func reduceMotionSkipsAnimation() {
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
  func applyRegistersEntireBatchBeforeFirstMutation() throws {
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
  func applyRetriesIncompleteSuccessfulMutation() {
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

  @Test("shouldSuppressNotification: holds intermediate events and consumes the target")
  func shouldSuppressNotificationHoldsIntermediateEventsAndConsumesTarget() {
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
    #expect(reconciler.shouldSuppressNotification(for: 1, actualFrame: target) == false)
  }
}
