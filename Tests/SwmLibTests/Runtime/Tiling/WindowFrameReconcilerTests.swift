import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("WindowFrameReconciler")
struct WindowFrameReconcilerTests {
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
