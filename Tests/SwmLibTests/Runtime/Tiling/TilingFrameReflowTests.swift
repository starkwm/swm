import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("Tiling frame reflow")
struct TilingFrameReflowTests {
  @Test("animation: paired completion notifications do not rescan or cancel other windows")
  func completionNotificationsPreserveOtherAnimations() {
    var frames: [CGWindowID: CGRect] = [
      1: CGRect(x: 0, y: 0, width: 400, height: 300),
      2: CGRect(x: 500, y: 100, width: 300, height: 200),
    ]
    var snapshots = 0
    let reconciler = WindowFrameReconciler(
      currentFrame: { frames[$0] },
      frameMutation: { id, target, _ in
        frames[id] = target
        return .success
      },
      reduceMotion: { false }
    )
    let tiling = makeTiling(
      windows: {
        snapshots += 1
        return [window(id: 1), window(id: 2)]
      },
      memberships: { [1: [10], 2: [10]] },
      frameReconciler: reconciler
    )
    tiling.initialize()
    let initialSnapshots = snapshots
    let start = ContinuousClock.now
    let firstTarget = CGRect(x: 500, y: 100, width: 300, height: 200)
    let secondTarget = CGRect(x: 0, y: 0, width: 400, height: 300)
    reconciler.animationDuration = 0.18
    reconciler.apply([1: firstTarget], at: start)
    reconciler.animationDuration = 0.3
    reconciler.apply([2: secondTarget], at: start)
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(180)))

    // A combined move and resize can deliver more than one notification at the final frame.
    tiling.windowFrameDidChange(1)
    tiling.windowFrameDidChange(1)
    tiling.windowFrameDidChange(1)

    #expect(snapshots == initialSnapshots)
    #expect(reconciler.frames(for: [2])[2] == secondTarget)
    reconciler.advanceAnimations(at: start.advanced(by: .milliseconds(300)))
    #expect(frames[2] == secondTarget)

    // A real user move after completion must still reach reconciliation immediately.
    frames[1]?.origin.x += 50
    tiling.windowFrameDidChange(1)
    #expect(snapshots == initialSnapshots + 1)
  }

  @Test("reconciliation preserves unrelated motion and invalidates changed membership only")
  func reconciliationPreservesUnchangedWindows() {
    var frames: [CGWindowID: CGRect] = [1: .zero, 2: .zero]
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10], 2: [10]]
    let reconciler = WindowFrameReconciler(
      currentFrame: { frames[$0] },
      frameMutation: { id, target, _ in
        frames[id] = target
        return .success
      },
      automaticallySchedule: false,
      reduceMotion: { false }
    )
    let tiling = makeTiling(
      windows: { [window(id: 1), window(id: 2)] },
      memberships: { memberships },
      frameReconciler: reconciler
    )
    tiling.initialize()
    reconciler.animationDuration = 1
    let target = CGRect(x: 100, y: 0, width: 100, height: 100)
    reconciler.apply([1: target, 2: target])
    tiling.reconcile()
    #expect(reconciler.isAnimating(1))
    #expect(reconciler.isAnimating(2))
    memberships[1] = [11]
    tiling.reconcile()
    #expect(!reconciler.isAnimating(1))
    #expect(reconciler.isAnimating(2))
    reconciler.cancelAnimations()
  }

  @Test("rule placement cancels only its window before applying a synchronous mutation")
  func rulePlacementCancelsBeforeMutation() throws {
    var frames: [CGWindowID: CGRect] = [1: .zero, 2: .zero]
    let reconciler = WindowFrameReconciler(
      currentFrame: { frames[$0] },
      frameMutation: { id, target, _ in
        frames[id] = target
        return .success
      },
      automaticallySchedule: false,
      reduceMotion: { false }
    )
    var placed = false
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]],
      frameReconciler: reconciler,
      rulePlacement: { _, id, _ in
        #expect(!reconciler.isAnimating(id))
        placed = true
        return .applied
      }
    )
    tiling.initialize()
    reconciler.animationDuration = 1
    reconciler.apply([1: CGRect(x: 100, y: 0, width: 100, height: 100)])
    try tiling.addRule(WindowRule.parse(arguments: ["grid=2:1:1:0:1:1"]))
    #expect(placed)
    reconciler.cancelAnimations()
  }

  @Test("unrelated reconciliation preserves explicitly floating window motion")
  func floatingAnimationSurvivesReconciliation() {
    var frames: [CGWindowID: CGRect] = [1: .zero, 2: .zero]
    let reconciler = WindowFrameReconciler(
      currentFrame: { frames[$0] },
      frameMutation: { id, target, _ in
        frames[id] = target
        return .success
      },
      automaticallySchedule: false,
      reduceMotion: { false }
    )
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]],
      frameReconciler: reconciler
    )
    tiling.initialize()
    #expect(tiling.setWindowLayout(.float, for: 1))
    reconciler.animationDuration = 1
    reconciler.apply([1: CGRect(x: 100, y: 0, width: 100, height: 100)])
    tiling.reconcile()
    #expect(reconciler.isAnimating(1))
    reconciler.cancelAnimations()
  }

  @Test("transiently omitted windows stop animating even when membership is unchanged")
  func omittedWindowStopsAnimating() {
    var candidate = window(id: 1)
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in .zero },
      frameMutation: { _, _, _ in .success },
      automaticallySchedule: false,
      reduceMotion: { false }
    )
    let tiling = makeTiling(
      windows: { [candidate] },
      memberships: { [1: [10]] },
      frameReconciler: reconciler
    )
    tiling.initialize()
    reconciler.animationDuration = 1
    reconciler.apply([1: CGRect(x: 100, y: 0, width: 100, height: 100)])
    candidate = window(id: 1, displayID: nil)
    tiling.reconcile()
    #expect(reconciler.isIdle)
  }

  @Test("placement rules defer during a drag and apply after release")
  func placementWaitsForInteraction() throws {
    let reconciler = WindowFrameReconciler(
      currentFrame: { _ in .zero },
      frameMutation: { _, _, _ in .success },
      automaticallySchedule: false,
      reduceMotion: { false }
    )
    var placements = 0
    let tiling = makeTiling(
      frameReconciler: reconciler,
      rulePlacement: { _, _, _ in
        placements += 1
        return .applied
      }
    )
    tiling.initialize()
    reconciler.onInteractionEnded = { [weak tiling] in tiling?.reconcileAndReflowVisibleSpaces() }
    reconciler.beginInteraction(for: 1)
    try tiling.addRule(WindowRule.parse(arguments: ["grid=2:1:1:0:1:1"]))
    #expect(tiling.isInteractingWithWindow(1))
    #expect(placements == 0)
    reconciler.endInteractions()
    #expect(!tiling.isInteractingWithWindow(1))
    #expect(placements == 1)
  }

  @Test("directional swap: exchanges complete frames in a floating layout")
  func directionalSwapExchangesFloatingFrames() {
    var framesByWindowID: [CGWindowID: CGRect] = [
      1: CGRect(x: 0, y: 0, width: 400, height: 300),
      2: CGRect(x: 500, y: 100, width: 300, height: 200),
    ]
    let frameReconciler = WindowFrameReconciler(
      currentFrame: { framesByWindowID[$0] },
      frameMutation: { windowID, targetFrame, _ in
        framesByWindowID[windowID] = targetFrame
        return .success
      }
    )
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]],
      frameReconciler: frameReconciler
    )
    tiling.initialize()

    #expect(tiling.swapWindow(1, in: .right))
    #expect(
      framesByWindowID
        == [
          1: CGRect(x: 500, y: 100, width: 300, height: 200),
          2: CGRect(x: 0, y: 0, width: 400, height: 300),
        ]
    )
    #expect(tiling.swapWindow(1, in: .right) == false)
  }
}
