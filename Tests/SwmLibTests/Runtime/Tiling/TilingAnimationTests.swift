import CoreGraphics
import Testing

@testable import SwmLib

extension TilingTests {
  @Test("animateFrame: one-point moves are not skipped")
  func animateFrameOnePointMovesAreNotSkipped() {
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
    "animateFrame: disabled animation and Reduce Motion use the synchronous fallback",
    arguments: [false, true]
  )
  func animateFrameDisabledAnimationAndReduceMotionUseTheSynchronousFallback(reduceMotion: Bool) {
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

  @Test(
    "cancelAnimation: tiling changes discard old destinations",
    arguments: ["window-float", "space-float", "all-float", "membership", "direct-command"]
  )
  func cancelAnimationTilingChangesDiscardOldDestinations(change: String) {
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
}
