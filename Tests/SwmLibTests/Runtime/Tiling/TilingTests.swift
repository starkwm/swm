import AppKit
import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("Tiling")
struct TilingTests {
  @Test("initialize: excludes ineligible windows from disabled Space geometry")
  func initializeExcludesIneligibleWindowsFromDisabledSpaceGeometry() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10, 11], 3: []]
    )

    tiling.initialize()

    #expect(tiling.layoutPlan(for: layoutID(10)) == .disabled)
    #expect(tiling.setLayout(.master, for: 10))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )
  }

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

  @Test("reconcile: cancels animation only for changed membership")
  func reconcileCancelsAnimationOnlyForChangedMembership() {
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

  @Test("reconcile: preserves floating window animation")
  func reconcilePreservesFloatingWindowAnimation() {
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

  @Test("reconcile: cancels animation for transiently omitted windows")
  func reconcileCancelsAnimationForTransientlyOmittedWindows() {
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

  @Test("reconcile: applies deferred placement after interaction ends")
  func reconcileAppliesDeferredPlacementAfterInteractionEnds() throws {
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

  @Test("reconcile: preserves surviving order and enablement across migration")
  func reconcilePreservesSurvivingOrderAndEnablementAcrossMigration() {
    var windows = [window(id: 1), window(id: 2)]
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10], 2: [10]]
    let tiling = makeTiling(
      windows: { windows },
      memberships: { memberships }
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    tiling.windowDidFocus(1)

    windows.append(window(id: 3))
    memberships[2] = [11]
    memberships[3] = [10]
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )
    #expect(tiling.layoutPlan(for: layoutID(11)) == .disabled)
  }

  @Test(
    "reconcile: preserves order and settings across batched removals"
  )
  func reconcilePreservesOrderAndSettingsAcrossBatchedRemovals() {
    var candidates = (1...6).map { window(id: CGWindowID($0)) }
    let tiling = makeTiling(
      windows: { candidates },
      memberships: {
        Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, Set([UInt64(10)])) })
      }
    )
    tiling.initialize()
    #expect(tiling.setLayout(.master, for: 10))
    #expect(tiling.changeMasterRatio(.absolute(0.65), for: 10))
    #expect(tiling.swapWindowWithMaster(4))
    tiling.windowDidFocus(3)

    candidates = [
      window(id: 1, isMinimized: true), window(id: 3), window(id: 4), window(id: 7), window(id: 8),
    ]
    tiling.reconcile()
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            4: CGRect(x: 0, y: 0, width: 650, height: 800),
            3: CGRect(x: 650, y: 0, width: 350, height: 267),
            7: CGRect(x: 650, y: 267, width: 350, height: 266),
            8: CGRect(x: 650, y: 533, width: 350, height: 267),
          ])
        )
    )

    candidates[0] = window(id: 1)
    tiling.reconcile()
    #expect(tiling.cycledWindowID(from: 4, in: .next) == 3)
    #expect(tiling.cycledWindowID(from: 3, in: .next) == 7)
    #expect(tiling.cycledWindowID(from: 7, in: .next) == 8)
    #expect(tiling.cycledWindowID(from: 8, in: .next) == 1)
    #expect(tiling.cycledWindowID(from: 1, in: .next) == 4)

    candidates = [window(id: 9)]
    tiling.reconcile()
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            9: CGRect(x: 0, y: 0, width: 1000, height: 800)
          ])
        )
    )
  }

  @Test("reconcile: a new window splits the focused leaf")
  func reconcileANewWindowSplitsTheFocusedLeaf() {
    var windows = [window(id: 1), window(id: 2), window(id: 3)]
    let tiling = makeTiling(
      windows: { windows },
      memberships: { [1: [10], 2: [10], 3: [10], 4: [10]] }
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)
    tiling.windowDidFocus(1)

    windows.append(window(id: 4))
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 400),
            4: CGRect(x: 0, y: 400, width: 500, height: 400),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            3: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }

  @Test("reconcile: preserves minimized leaves but omits them from geometry")
  func reconcilePreservesMinimizedLeavesButOmitsThemFromGeometry() {
    var windows = [window(id: 1), window(id: 2, isMinimized: true)]
    let tiling = makeTiling(windows: { windows }, memberships: { [1: [10], 2: [10]] })
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )

    windows[1] = window(id: 2, isMinimized: false)
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )
  }

  @Test("reconcile: preserves native-fullscreen leaves at their prior position")
  func reconcilePreservesNativeFullscreenLeavesAtTheirPriorPosition() {
    let windows = [window(id: 1), window(id: 2), window(id: 3)]
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10], 2: [10], 3: [10]]
    let tiling = makeTiling(windows: { windows }, memberships: { memberships })
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    tiling.windowDidFocus(3)
    let initialPlan = tiling.layoutPlan(for: layoutID(10))

    memberships[1] = [12]
    tiling.reconcile()
    memberships[1] = [10]
    tiling.reconcile()

    #expect(tiling.layoutPlan(for: layoutID(10)) == initialPlan)
  }

  @Test("reconcile: preserves state while display ownership is unresolved")
  func reconcilePreservesStateWhileDisplayOwnershipIsUnresolved() {
    let windows = [window(id: 1), window(id: 2), window(id: 3)]
    var windowServerDisplayID = "display"
    let spaces = Spaces(activeSpaceID: nil)
    let tiling = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: windows,
          topology: SpaceTopology(
            spacesByID: [
              10: SpaceTopologyDescriptor(
                id: 10,
                displayID: windowServerDisplayID,
                type: .normal
              )
            ],
            visibleSpaceIDByDisplayID: [windowServerDisplayID: 10],
            spaceIDsByWindowID: [1: [10], 2: [10], 3: [10]],
            displaysByID: [
              "display": SpaceTopologyDisplay(
                visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
              )
            ]
          )
        )
      },
      spaces: spaces
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)
    let initialPlan = tiling.layoutPlan(for: layoutID(10))

    windowServerDisplayID = "stale-display"
    tiling.reconcile()

    windowServerDisplayID = "display"
    tiling.reconcile()

    #expect(tiling.layoutPlan(for: layoutID(10)) == initialPlan)
  }

  @Test("reconcile: tiles and migrates windows independently per monitor")
  func reconcileTilesAndMigratesWindowsIndependentlyPerMonitor() {
    var windows = [
      window(id: 1, displayID: "display-a"),
      window(id: 2, displayID: "display-a"),
      window(id: 3, displayID: "display-b"),
    ]
    let tiling = makeSharedSpaceTiling(windows: { windows })
    tiling.initialize()

    #expect(tiling.setLayout(.master, for: 10))
    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "display-a"))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )
    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "display-b"))
        == .layout(.frames([3: CGRect(x: 1_000, y: 0, width: 800, height: 800)]))
    )

    windows[1] = window(id: 2, displayID: "display-b")
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "display-a"))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )
    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "display-b"))
        == .layout(
          .frames([
            3: CGRect(x: 1_000, y: 0, width: 400, height: 800),
            2: CGRect(x: 1_400, y: 0, width: 400, height: 800),
          ])
        )
    )

    #expect(tiling.setLayout(.dwindle, for: 10))
  }

  @Test("reconcile: a new monitor inherits the layout selection")
  func reconcileANewMonitorInheritsTheLayoutSelection() {
    var displays = [
      "display-a": SpaceTopologyDisplay(
        visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
      )
    ]
    let tiling = makeSharedSpaceTiling(windows: { [] }, displays: { displays })
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    displays["display-b"] = SpaceTopologyDisplay(
      visibleFrame: CGRect(x: 1_000, y: 0, width: 800, height: 800)
    )
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "display-b")) == .layout(.frames([:]))
    )
  }

  @Test("reconcile: applies placement once per matching action change and window lifetime")
  func reconcileAppliesPlacementOncePerMatchingActionChangeAndWindowLifetime() throws {
    var candidate = window(id: 1)
    candidate.title = "Projects"
    var candidates = [candidate]
    var placements = [WindowRulePlacement]()
    let tiling = makeTiling(
      windows: { candidates },
      memberships: { [1: [10]] },
      rulePlacement: { placement, _, _ in
        placements.append(placement)
        return .applied
      }
    )
    try tiling.addRule(
      WindowRule.parse(arguments: ["label=grid", "title=^Projects$", "grid=2:1:1:0:1:1"])
    )
    #expect(placements.count == 1)
    tiling.reconcile()
    tiling.windowFrameDidChange(1)
    #expect(placements.count == 1)
    try tiling.addRule(WindowRule.parse(arguments: ["label=override", "grid=1:1:0:0:1:1"]))
    #expect(placements.count == 2)
    try tiling.removeRule(selector: "override")
    #expect(placements.count == 3)
    candidates[0].title = "Other"
    tiling.reconcile()
    #expect(placements.count == 3)
    candidates[0].title = "Projects"
    tiling.reconcile()
    #expect(placements.count == 4)
    candidates = []
    tiling.reconcile()
    candidates = [candidate]
    tiling.reconcile()
    #expect(placements.count == 5)
    try tiling.removeRule(selector: "grid")
    #expect(placements.count == 5)
  }

  @Test("reconcile: defers grids until floating and transfers tiled windows")
  func reconcileDefersGridsUntilFloatingAndTransfersTiledWindows() throws {
    var placements = [WindowRulePlacement]()
    let tiling = makeTiling(rulePlacement: { placement, _, _ in
      placements.append(placement)
      return .applied
    })
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    try tiling.addRule(WindowRule.parse(arguments: ["grid=2:1:1:0:1:1", "display=1"]))
    #expect(placements == [WindowRulePlacement(display: .index(1))])
    try tiling.addRule(WindowRule.parse(arguments: ["manage=off"]))
    #expect(placements.count == 2)
    #expect(placements.last?.grid != nil)
    tiling.reconcile()
    #expect(placements.count == 2)
    #expect(tiling.setWindowLayout(.tile, for: 1))
    try tiling.addRule(WindowRule.parse(arguments: ["grid=1:1:0:0:1:1"]))
    #expect(placements.count == 2)
    #expect(placements.last?.display == nil)
  }

  @Test("reconcile: retries deferred placement and stops after failure")
  func reconcileRetriesDeferredPlacementAndStopsAfterFailure() throws {
    var attempts = 0
    var result = WindowRulePlacementResult.deferred
    let tiling = makeTiling(rulePlacement: { _, _, _ in
      attempts += 1
      return result
    })
    try tiling.addRule(WindowRule.parse(arguments: ["grid=1:1:0:0:1:1"]))
    #expect(attempts == 1)
    tiling.reconcile()
    #expect(attempts == 2)
    result = .failed
    tiling.reconcile()
    #expect(attempts == 3)
    tiling.reconcile()
    #expect(attempts == 3)
  }

  @Test("reconcile: defers placement for unavailable windows")
  func reconcileDefersPlacementForUnavailableWindows() throws {
    var candidates = [window(id: 1, isMinimized: true)]
    var membership: Set<UInt64> = [10]
    var calls = 0
    let tiling = makeTiling(
      windows: { candidates },
      memberships: { [1: membership] },
      rulePlacement: { _, _, _ in
        calls += 1
        return .applied
      }
    )
    try tiling.addRule(WindowRule.parse(arguments: ["display=1"]))
    #expect(calls == 0)
    candidates = [window(id: 1)]
    membership = [12]
    tiling.reconcile()
    #expect(calls == 0)
    membership = [10]
    tiling.reconcile()
    #expect(calls == 1)
  }

  @Test("reconcile: refreshes transfer membership and grids floating destinations")
  func reconcileRefreshesTransferMembershipAndGridsFloatingDestinations() throws {
    var currentDisplay = "left"
    var currentSpace: UInt64 = 10
    var displayIDs = ["left"]
    var placements = [WindowRulePlacement]()
    let tiling = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: [window(id: 1, displayID: currentDisplay), window(id: 2, displayID: "left")],
          topology: SpaceTopology(
            spacesByID: [
              10: SpaceTopologyDescriptor(id: 10, displayID: "left", type: .normal),
              11: SpaceTopologyDescriptor(id: 11, displayID: "right", type: .normal),
            ],
            visibleSpaceIDByDisplayID: ["left": 10, "right": 11],
            spaceIDsByWindowID: [1: [currentSpace], 2: [10]],
            displaysByID: [
              "left": SpaceTopologyDisplay(
                visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
              ),
              "right": SpaceTopologyDisplay(
                visibleFrame: CGRect(x: 1_000, y: 0, width: 1_000, height: 800)
              ),
            ]
          )
        )
      },
      spaces: Spaces(activeSpaceID: nil),
      rulePlacement: { placement, id, destination in
        if id == 1 {
          #expect(destination == layoutID(11, displayID: "right"))
          placements.append(placement)
          if placement.display != nil {
            currentDisplay = "right"
            currentSpace = 11
          }
        }
        return .applied
      },
      ruleDisplayIDs: { displayIDs }
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 11)
    try tiling.addRule(WindowRule.parse(arguments: ["display=2", "grid=2:1:1:0:1:1"]))
    #expect(placements.isEmpty)
    displayIDs.append("right")
    tiling.reconcileAndReflowVisibleSpaces()
    #expect(placements == [WindowRulePlacement(display: .index(2))])
    #expect(
      tiling.layoutPlan(for: layoutID(11, displayID: "right"))
        == .layout(
          .frames([
            1: CGRect(x: 1_000, y: 0, width: 1_000, height: 800)
          ])
        )
    )
    tiling.setLayout(.master, for: 10)
    #expect(
      tiling.layoutPlan(for: layoutID(10, displayID: "left"))
        == .layout(
          .frames([
            2: CGRect(x: 0, y: 0, width: 1_000, height: 800)
          ])
        )
    )
    try tiling.addRule(WindowRule.parse(arguments: ["manage=off"]))
    #expect(placements.count == 2)
    #expect(placements.last?.grid != nil)
    #expect(placements.last?.display == nil)
    // Moving the window manually back must not replay the display action.
    currentDisplay = "left"
    currentSpace = 10
    tiling.reconcile()
    #expect(placements.count == 2)
  }

  @Test("reconcile: defers a previous grid after transfer to a tiled layout")
  func reconcileDefersAPreviousGridAfterTransferToATiledLayout() throws {
    var placements = [WindowRulePlacement]()
    let tiling = makeTiling(rulePlacement: { placement, _, _ in
      placements.append(placement)
      return .applied
    })
    try tiling.addRule(WindowRule.parse(arguments: ["grid=2:1:1:0:1:1"]))
    #expect(placements.count == 1)
    tiling.setLayout(.master, for: 10)
    try tiling.addRule(WindowRule.parse(arguments: ["display=1"]))
    #expect(placements.count == 2)
    #expect(placements.last?.grid == nil)
    try tiling.addRule(WindowRule.parse(arguments: ["manage=off"]))
    #expect(placements.count == 3)
    #expect(placements.last?.grid != nil)
    #expect(placements.last?.display == nil)
  }

  @Test("reconcile: applies rules before layout after creation and title changes")
  func reconcileAppliesRulesBeforeLayoutAfterCreationAndTitleChanges() throws {
    var candidates = [window(id: 1)]
    let tiling = makeTiling(windows: { candidates }, memberships: { [1: [10], 2: [10], 3: [10]] })
    try tiling.addRule(WindowRule.parse(arguments: ["title=^Preferences$", "manage=off"]))
    tiling.setLayout(.dwindle, for: 10)
    var preferences = window(id: 2)
    preferences.title = "Preferences"
    candidates.append(preferences)
    tiling.reconcile()
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 1_000, height: 800)
          ])
        )
    )
    candidates[1].title = "Document"
    WindowLifecycleHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      tiling: tiling
    )
    .handle(.titleChanged(2))
    #expect(tiling.cycledWindowID(from: 1, in: .next) == 2)
    candidates.append(window(id: 3, isResizable: false))
    try tiling.addRule(WindowRule.parse(arguments: ["manage=on"]))
    #expect(!tiling.setWindowLayout(.tile, for: 3))
    #expect(tiling.cycledWindowID(from: 2, in: .next) == 1)
  }

  @Test("addRule: cancels animation before synchronous placement")
  func addRuleCancelsAnimationBeforeSynchronousPlacement() throws {
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

  @Test(
    "addRule/removeRule: resolves precedence and restores layout defaults",
    arguments: [LayoutSelection.master, .monocle, .dwindle]
  )
  func addRuleRemoveRuleResolvesPrecedenceAndRestoresLayoutDefaults(layout: LayoutSelection) throws
  {
    var finder = window(id: 2)
    finder.app = "Finder"
    let tiling = makeTiling(windows: [window(id: 1), finder], memberships: [1: [10], 2: [10]])
    tiling.initialize()
    tiling.setLayout(layout, for: 10)
    let initial = tiling.layoutPlan(for: layoutID(10))
    try tiling.addRule(WindowRule.parse(arguments: ["label=finder", "app=^Finder$", "manage=off"]))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 1_000, height: 800)
          ])
        )
    )
    #expect(tiling.cycledWindowID(from: 1, in: .next) == nil)
    try tiling.addRule(
      WindowRule.parse(arguments: ["label=exception", "app=^Finder$", "manage=on"])
    )
    #expect(tiling.layoutPlan(for: layoutID(10)) == initial)
    try tiling.removeRule(selector: "2")
    #expect(tiling.layoutPlan(for: layoutID(10)) != initial)
    try tiling.removeRule(selector: "finder")
    #expect(tiling.layoutPlan(for: layoutID(10)) == initial)
  }

  @Test("setLayout: retains dwindle selection and plans its geometry")
  func setLayoutRetainsDwindleSelectionAndPlansItsGeometry() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3), window(id: 4)],
      memberships: [1: [10], 2: [10], 3: [10], 4: [10]]
    )
    tiling.initialize()

    #expect(tiling.setLayout(.dwindle, for: 10))
    #expect(tiling.setLayout(.dwindle, for: 99) == false)

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            3: CGRect(x: 500, y: 400, width: 250, height: 400),
            4: CGRect(x: 750, y: 400, width: 250, height: 400),
          ])
        )
    )

    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            3: CGRect(x: 500, y: 400, width: 250, height: 400),
            4: CGRect(x: 750, y: 400, width: 250, height: 400),
          ])
        )
    )
  }

  @Test("setLayoutForSpaces: apply layout settings to current and future Spaces")
  func setLayoutForSpacesApplyLayoutSettingsToCurrentAndFutureSpaces() {
    var spaceIDs = Set([UInt64(10)])
    var visibleSpaceID = UInt64(10)
    var visibleFrame = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    let spaces = Spaces(activeSpaceID: nil)
    let tiling = Tiling(
      snapshot: {
        TilingReconciliationSnapshot(
          windows: [window(id: 1), window(id: 2)],
          topology: SpaceTopology(
            spacesByID: Dictionary(
              uniqueKeysWithValues: spaceIDs.map {
                ($0, SpaceTopologyDescriptor(id: $0, displayID: "display", type: .normal))
              }
            ),
            visibleSpaceIDByDisplayID: ["display": visibleSpaceID],
            spaceIDsByWindowID: [1: [visibleSpaceID], 2: [visibleSpaceID]],
            displaysByID: [
              "display": SpaceTopologyDisplay(
                visibleFrame: visibleFrame
              )
            ]
          )
        )
      },
      spaces: spaces
    )
    tiling.initialize()

    tiling.setLayoutForSpaces(.master)
    tiling.setMasterRatioForAllSpaces(0.65)
    tiling.setMasterPlacementForAllSpaces(.bottom)
    tiling.setSplitDirectionPreservationForAllSpaces(true)

    let expectedPlan = TilingLayoutPlan.layout(
      .frames([
        1: CGRect(x: 0, y: 280, width: 1_000, height: 520),
        2: CGRect(x: 0, y: 0, width: 1_000, height: 280),
      ])
    )
    #expect(tiling.layoutPlan(for: layoutID(10)) == expectedPlan)

    spaceIDs.insert(11)
    visibleSpaceID = 11
    tiling.reconcile()

    #expect(tiling.layoutPlan(for: layoutID(11)) == expectedPlan)

    tiling.setLayout(.dwindle, for: 11)
    visibleFrame = CGRect(x: 0, y: 0, width: 600, height: 1_000)
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(11))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 300, height: 1_000),
            2: CGRect(x: 300, y: 0, width: 300, height: 1_000),
          ])
        )
    )
  }

  @Test(
    "changeMasterRatio/setMasterPlacement: update ratio and placement for a Space",
    arguments: [MasterPlacement.right, .top, .bottom]
  )
  func changeMasterRatioSetMasterPlacementUpdateRatioAndPlacementForASpace(
    placement: MasterPlacement
  ) {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    #expect(tiling.changeMasterRatio(.absolute(0.6), for: 10))
    #expect(tiling.setMasterPlacement(placement, for: 10))
    let frames: [CGWindowID: CGRect]
    switch placement {
    case .right:
      frames = [
        1: CGRect(x: 400, y: 0, width: 600, height: 800),
        2: CGRect(x: 0, y: 0, width: 400, height: 400),
        3: CGRect(x: 0, y: 400, width: 400, height: 400),
      ]
    case .top:
      frames = [
        1: CGRect(x: 0, y: 0, width: 1000, height: 480),
        2: CGRect(x: 0, y: 480, width: 500, height: 320),
        3: CGRect(x: 500, y: 480, width: 500, height: 320),
      ]
    case .bottom:
      frames = [
        1: CGRect(x: 0, y: 320, width: 1000, height: 480),
        2: CGRect(x: 0, y: 0, width: 500, height: 320),
        3: CGRect(x: 500, y: 0, width: 500, height: 320),
      ]
    default:
      Issue.record("unexpected placement")
      return
    }
    #expect(tiling.layoutPlan(for: layoutID(10)) == .layout(.frames(frames)))
  }

  @Test("cycleMasterPlacement: cycle placement clockwise and counter-clockwise")
  func cycleMasterPlacementCyclePlacementClockwiseAndCounterClockwise() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(tiling.cycleMasterPlacement(.next, for: 10) == .top)
    #expect(tiling.cycleMasterPlacement(.prev, for: 10) == .left)
  }

  @Test("swapWindow: exchanges complete frames in a floating layout")
  func swapWindowExchangesCompleteFramesInAFloatingLayout() {
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

  @Test("swapWindow: exchanges neighbouring windows in master")
  func swapWindowExchangesNeighbouringWindowsInMaster() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(tiling.swapWindow(2, in: .down))
    #expect(tiling.swapWindow(2, in: .down) == false)
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 400),
            2: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }

  @Test("swapWindow: exchanges neighbouring windows in dwindle")
  func swapWindowExchangesNeighbouringWindowsInDwindle() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    #expect(tiling.swapWindow(2, in: .down))
    #expect(tiling.swapWindow(99, in: .left) == false)
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 400),
            2: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }

  @Test("swapWindowWithMaster: skips rule floated leaves")
  func swapWindowWithMasterSkipsRuleFloatedLeaves() throws {
    var finder = window(id: 1)
    finder.app = "Finder"
    let tiling = makeTiling(
      windows: [finder, window(id: 2), window(id: 3), window(id: 4)],
      memberships: [1: [10], 2: [10], 3: [10], 4: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    try tiling.addRule(WindowRule.parse(arguments: ["app=^Finder$", "manage=off"]))
    #expect(tiling.masterWindowID(inLayoutContaining: 3) == 2)
    #expect(tiling.swapWindowWithMaster(3))
    #expect(tiling.masterWindowID(inLayoutContaining: 3) == 3)
    #expect(!tiling.swapWindowWithMaster(1))
    #expect(!tiling.swapWindowWithMaster(99))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            3: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            4: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }

  @Test("masterWindowID: find the first available master window")
  func masterWindowIDFindTheFirstAvailableMasterWindow() {
    let tiling = makeTiling(
      windows: [window(id: 1, isMinimized: true), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(tiling.masterWindowID(inLayoutContaining: 3) == 2)
    #expect(tiling.setWindowLayout(.float, for: 2))
    #expect(tiling.masterWindowID(inLayoutContaining: 3) == 3)

    tiling.setLayout(.dwindle, for: 10)
    #expect(tiling.masterWindowID(inLayoutContaining: 3) == nil)
  }

  @Test("setWindowLayout: retains manual overrides through rule edits until window closure")
  func setWindowLayoutRetainsManualOverridesThroughRuleEditsUntilWindowClosure() throws {
    var candidates = [window(id: 1), window(id: 2)]
    let tiling = makeTiling(windows: { candidates }, memberships: { [1: [10], 2: [10]] })
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    let initial = tiling.layoutPlan(for: layoutID(10))
    try tiling.addRule(WindowRule.parse(arguments: ["label=all", "manage=off"]))
    #expect(tiling.setWindowLayout(.toggle, for: 1))
    #expect(tiling.setWindowLayout(.tile, for: 2))
    tiling.reconcile()
    #expect(tiling.layoutPlan(for: layoutID(10)) == initial)
    #expect(tiling.setWindowLayout(.float, for: 2))
    try tiling.removeRule(selector: "all")
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 1_000, height: 800)
          ])
        )
    )
    candidates.removeLast()
    tiling.reconcile()
    candidates.append(window(id: 2))
    tiling.reconcile()
    #expect(tiling.layoutPlan(for: layoutID(10)) == initial)
  }

  @Test("setWindowLayout: float removes a window and tile restores it")
  func setWindowLayoutFloatRemovesAWindowAndTileRestoresIt() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    let initialPlan = tiling.layoutPlan(for: layoutID(10))

    #expect(tiling.setWindowLayout(.float, for: 2))
    tiling.reconcile()
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )

    #expect(tiling.setWindowLayout(.tile, for: 2))
    #expect(tiling.layoutPlan(for: layoutID(10)) == initialPlan)
  }

  @Test("setWindowLayout: toggle alternates floating participation")
  func setWindowLayoutToggleAlternatesFloatingParticipation() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2)],
      memberships: [1: [10], 2: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    let tiledPlan = tiling.layoutPlan(for: layoutID(10))

    #expect(tiling.setWindowLayout(.toggle, for: 2))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )

    #expect(tiling.setWindowLayout(.toggle, for: 2))
    #expect(tiling.layoutPlan(for: layoutID(10)) == tiledPlan)
  }

  @Test("setWindowLayout: floating the insertion anchor excludes it from focused insertion")
  func setWindowLayoutFloatingTheInsertionAnchorExcludesItFromFocusedInsertion() {
    var windows = [window(id: 1), window(id: 2), window(id: 3)]
    let tiling = makeTiling(
      windows: { windows },
      memberships: { [1: [10], 2: [10], 3: [10], 4: [10]] }
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)
    tiling.windowDidFocus(1)

    #expect(tiling.setWindowLayout(.float, for: 1))
    windows.append(window(id: 4))
    tiling.reconcile()

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            2: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 400),
            4: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }

  @Test("cycledWindowID: follows layout order, wraps, and skips unavailable windows")
  func cycledWindowIDFollowsLayoutOrderWrapsAndSkipsUnavailableWindows() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3, isMinimized: true)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    #expect(tiling.cycledWindowID(from: 1, in: .next) == 2)
    #expect(tiling.cycledWindowID(from: 2, in: .next) == 1)
    #expect(tiling.cycledWindowID(from: 1, in: .prev) == 2)

    #expect(tiling.setWindowLayout(.float, for: 2))
    #expect(tiling.cycledWindowID(from: 1, in: .next) == nil)
  }

  @Test("cycledWindowID: includes fixed-size windows only in floating layouts")
  func cycledWindowIDIncludesFixedSizeWindowsOnlyInFloatingLayouts() {
    var windows = [
      window(id: 1), window(id: 2, isResizable: false),
      window(id: 3, isMinimized: true, isResizable: false),
      window(id: 4, isResizable: false),
    ]
    let tiling = makeTiling(
      windows: { windows },
      memberships: { [1: [10], 2: [10], 3: [10], 4: [20]] }
    )
    tiling.initialize()

    #expect(tiling.cycledWindowID(from: 1, in: .next) == 2)
    #expect(tiling.cycledWindowID(from: 2, in: .next) == 1)
    #expect(tiling.cycledWindowID(from: 1, in: .prev) == 2)
    #expect(tiling.cycledWindowID(from: 2, in: .prev) == 1)

    tiling.setLayout(.master, for: 10)
    #expect(tiling.cycledWindowID(from: 1, in: .next) == nil)
    #expect(tiling.cycledWindowID(from: 2, in: .next) == nil)
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )

    tiling.setLayout(.float, for: 10)
    #expect(tiling.cycledWindowID(from: 1, in: .next) == 2)
    windows.removeAll { $0.id == 1 }
    tiling.reconcile()
    #expect(tiling.cycledWindowID(from: nil, in: .next, fallbackSpaceID: 10) == 2)
    #expect(tiling.cycledWindowID(from: 2, in: .next) == nil)
    windows.removeAll { $0.id == 2 }
    tiling.reconcile()
    #expect(tiling.cycledWindowID(from: nil, in: .next, fallbackSpaceID: 10) == nil)
  }

  @Test("cycledWindowID: resumes on the active Space after the focused window closes")
  func cycledWindowIDResumesOnTheActiveSpaceAfterTheFocusedWindowCloses() {
    var windows = [window(id: 1), window(id: 2), window(id: 3), window(id: 4, isMinimized: true)]
    let tiling = makeTiling(
      windows: { windows },
      memberships: { [1: [10], 2: [10], 3: [10], 4: [10]] }
    )
    tiling.initialize()
    tiling.windowDidFocus(1)
    windows.removeAll { $0.id == 1 }
    tiling.reconcile()

    #expect(tiling.cycledWindowID(from: nil, in: .next, fallbackSpaceID: 10) == 2)
    #expect(tiling.cycledWindowID(from: nil, in: .prev, fallbackSpaceID: 10) == 3)
    #expect(tiling.cycledWindowID(from: 1, in: .next, fallbackSpaceID: 10) == 2)
    #expect(tiling.cycledWindowID(from: 2, in: .next) == 3)
    #expect(tiling.cycledWindowID(from: 3, in: .next) == 2)
    #expect(tiling.cycledWindowID(from: nil, in: .next, fallbackSpaceID: 99) == nil)

    windows.removeAll { $0.id == 3 }
    tiling.reconcile()
    #expect(tiling.cycledWindowID(from: nil, in: .next, fallbackSpaceID: 10) == 2)
    #expect(tiling.cycledWindowID(from: 2, in: .next) == nil)

    windows.removeAll { $0.id == 2 }
    tiling.reconcile()
    #expect(tiling.cycledWindowID(from: nil, in: .next, fallbackSpaceID: 10) == nil)
  }

  @Test("swapWindowInOrder: exchanges adjacent leaves and wraps")
  func swapWindowInOrderExchangesAdjacentLeavesAndWraps() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)

    #expect(tiling.swapWindowInOrder(1, in: .prev))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            3: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            1: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )

    tiling.setLayout(.float, for: 10)
    #expect(tiling.swapWindowInOrder(1, in: .next) == false)
  }

  @Test("changeDwindleSplitRatio: adjust a window's nearest split")
  func changeDwindleSplitRatioAdjustAWindowsNearestSplit() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    #expect(tiling.changeDwindleSplitRatio(.relative(0.2), for: 1) == 0.7)
    #expect(tiling.changeDwindleSplitRatio(.absolute(0.4), for: 99) == nil)
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 700, height: 800),
            2: CGRect(x: 700, y: 0, width: 300, height: 400),
            3: CGRect(x: 700, y: 400, width: 300, height: 400),
          ])
        )
    )
  }

  @Test("toggleDwindleSplit: toggle and retain the nearest dynamic split")
  func toggleDwindleSplitToggleAndRetainTheNearestDynamicSplit() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    #expect(tiling.toggleDwindleSplit(for: 2))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 250, height: 800),
            3: CGRect(x: 750, y: 0, width: 250, height: 800),
          ])
        )
    )

    #expect(tiling.toggleDwindleSplit(for: 2))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            2: CGRect(x: 500, y: 0, width: 500, height: 400),
            3: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }

  @Test("swapDwindleSplit: swap the nearest sibling subtrees")
  func swapDwindleSplitSwapTheNearestSiblingSubtrees() {
    let tiling = makeTiling(
      windows: [window(id: 1), window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)

    #expect(tiling.swapDwindleSplit(for: 2))
    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 400),
            2: CGRect(x: 500, y: 400, width: 500, height: 400),
          ])
        )
    )
  }

  @Test(
    "windowDidFocus: retains pending focus unless a newer focus event supersedes it",
    arguments: [false, true]
  )
  func windowDidFocusRetainsPendingFocusUnlessANewerFocusEventSupersedesIt(focusChanged: Bool) {
    var windows = [window(id: 1)]
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10]]
    let tiling = makeTiling(windows: { windows }, memberships: { memberships })
    tiling.initialize()
    tiling.setLayout(.dwindle, for: 10)
    tiling.windowDidFocus(1)

    windows.append(window(id: 2))
    tiling.reconcile()
    tiling.windowDidFocus(2)
    tiling.reconcile()
    if focusChanged {
      tiling.windowDidFocus(1)
    }

    memberships[2] = [10]
    tiling.reconcile()
    windows.append(window(id: 3))
    memberships[3] = [10]
    tiling.reconcile()

    let expectedFrames: [CGWindowID: CGRect] =
      focusChanged
      ? [
        1: CGRect(x: 0, y: 0, width: 500, height: 400),
        3: CGRect(x: 0, y: 400, width: 500, height: 400),
        2: CGRect(x: 500, y: 0, width: 500, height: 800),
      ]
      : [
        1: CGRect(x: 0, y: 0, width: 500, height: 800),
        2: CGRect(x: 500, y: 0, width: 500, height: 400),
        3: CGRect(x: 500, y: 400, width: 500, height: 400),
      ]
    #expect(tiling.layoutPlan(for: layoutID(10)) == .layout(.frames(expectedFrames)))
  }

  @Test("windowFrameDidChange: suppresses failed settlement feedback")
  func windowFrameDidChangeSuppressesFailedSettlementFeedback() async throws {
    let app = AnimationTestApp(processID: 1)
    app.clampWrites = true
    let reconciler = makeDeliveryReconciler(app)
    var snapshots = 0
    let tiling = makeTiling(
      windows: {
        snapshots += 1
        return [window(id: 1)]
      },
      memberships: { [1: [10]] },
      frameReconciler: reconciler
    )
    tiling.initialize()
    let before = snapshots
    reconciler.apply([1: animationFrame(100)])
    try await waitForAnimation { reconciler.isIdle }
    for _ in 0..<10 { tiling.windowFrameDidChange(1) }
    #expect(snapshots == before)
    #expect(app.writeCount == 2)
  }

  @Test(
    "windowFrameDidChange: paired completion notifications do not rescan or cancel other windows"
  )
  func windowFrameDidChangePairedCompletionNotificationsDoNotRescanOrCancelOtherWindows() {
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

  @Test(
    "layoutPlan: returns no frames for an empty automatic layout",
    arguments: [LayoutSelection.master, .dwindle, .monocle]
  )
  func layoutPlanReturnsNoFramesForAnEmptyAutomaticLayout(selection: LayoutSelection) {
    let tiling = makeTiling(windows: [], memberships: [:])
    tiling.initialize()
    #expect(tiling.setLayout(selection, for: 10))
    #expect(tiling.layoutPlan(for: layoutID(10)) == .layout(.frames([:])))
  }

  @Test("layoutPlan: requires a visible Space")
  func layoutPlanRequiresAVisibleSpace() {
    let hiddenTiling = makeTiling(visibleSpaceID: 11)
    hiddenTiling.initialize()
    hiddenTiling.setLayout(.master, for: 10)

    #expect(hiddenTiling.layoutPlan(for: layoutID(10)) == .notVisible)
  }

  @Test(
    "layoutPlan: applies padding while ignoring gaps in single-tile and monocle layouts",
    arguments: [
      (LayoutSelection.master, [CGWindowID(1)]),
      (.dwindle, [1]), (.monocle, [1, 2, 3]),
    ]
  )
  func layoutPlanAppliesPaddingWhileIgnoringGapsInSingleTileAndMonocleLayouts(
    selection: LayoutSelection,
    windowIDs: [CGWindowID]
  ) {
    let spaces = Spaces(activeSpaceID: nil)
    spaces.setPadding(SpacePadding(top: 10, bottom: 20, left: 30, right: 40), for: 10)
    spaces.setGap(50, for: 10)
    let tiling = makeTestTiling(
      spaces: spaces,
      windows: windowIDs.map { window(id: $0) },
      topology: SpaceTopology(
        spacesByID: [10: SpaceTopologyDescriptor(id: 10, displayID: "display", type: .normal)],
        visibleSpaceIDByDisplayID: ["display": 10],
        spaceIDsByWindowID: Dictionary(
          uniqueKeysWithValues: windowIDs.map { ($0, Set([UInt64(10)])) }
        ),
        displaysByID: [
          "display": SpaceTopologyDisplay(
            visibleFrame: CGRect(x: -300, y: 24, width: 300, height: 200)
          )
        ]
      )
    )
    tiling.initialize()
    #expect(tiling.setLayout(selection, for: 10))
    let expected = Dictionary(
      uniqueKeysWithValues: windowIDs.map {
        ($0, CGRect(x: -270, y: 34, width: 230, height: 170))
      }
    )
    #expect(tiling.layoutPlan(for: layoutID(10)) == .layout(.frames(expected)))
  }

  @Test("membership polling: reflows without lifecycle events")
  func membershipPollingReflowsWithoutLifecycleEvents() async throws {
    let windows = [window(id: 1), window(id: 2), window(id: 3)]
    var memberships: [CGWindowID: Set<UInt64>] = [1: [10], 2: [10], 3: [11]]
    var framesByWindowID: [CGWindowID: CGRect] = [
      1: .zero,
      2: .zero,
      3: .zero,
    ]
    let frameReconciler = WindowFrameReconciler(
      currentFrame: { framesByWindowID[$0] },
      frameMutation: { windowID, targetFrame, _ in
        framesByWindowID[windowID] = targetFrame
        return .success
      }
    )
    let tiling = makeTiling(
      windows: { windows },
      memberships: { memberships },
      frameReconciler: frameReconciler
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    tiling.windowFrameDidChange(2)

    memberships[2] = [11]
    for _ in 0..<100 where framesByWindowID[1]?.width != 1_000 {
      try await Task.sleep(for: .milliseconds(10))
    }

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(.frames([1: CGRect(x: 0, y: 0, width: 1_000, height: 800)]))
    )
    #expect(framesByWindowID[1] == CGRect(x: 0, y: 0, width: 1_000, height: 800))

    framesByWindowID[3] = CGRect(x: 100, y: 100, width: 300, height: 300)
    memberships[3] = [10]
    for _ in 0..<100 where framesByWindowID[3]?.origin.x != 500 {
      try await Task.sleep(for: .milliseconds(10))
    }

    #expect(
      tiling.layoutPlan(for: layoutID(10))
        == .layout(
          .frames([
            1: CGRect(x: 0, y: 0, width: 500, height: 800),
            3: CGRect(x: 500, y: 0, width: 500, height: 800),
          ])
        )
    )
    #expect(framesByWindowID[3] == CGRect(x: 500, y: 0, width: 500, height: 800))
  }
}
