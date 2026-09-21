import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("Window rule placement")
struct WindowRulePlacementTests {
  @Test("Properties compose independently across matching rules")
  func composition() throws {
    let rules = try [
      ["manage=off", "display=1"], ["grid=2:1:1:0:1:1"], ["display=2"],
      ["app=^Other$", "manage=on", "grid=1:1:0:0:1:1"],
    ].map { try WindowRule.parse(arguments: $0) }
    let resolved = WindowRuleActions.resolve(rules, for: window(id: 1))
    #expect(resolved.manage == false)
    #expect(resolved.placement.display == .index(2))
    #expect(resolved.placement.grid == WindowGrid(argument: "2:1:1:0:1:1"))
  }

  @Test(
    "Invalid placement actions fail before registration",
    arguments: [
      ["grid=0:1:0:0:1:1"], ["grid=1:2:3"], ["grid=1:1:a:0:1:1"],
      ["display=0"], ["display=-1"], ["display=next"], ["display=not-a-uuid"],
      ["display=1", "display=2"], ["grid!=1:1:0:0:1:1"], ["app=Finder"],
    ]
  )
  func invalid(arguments: [String]) {
    #expect(throws: IPCCommandError.self) { try WindowRule.parse(arguments: arguments) }
  }

  @Test("Display indexes and UUIDs resolve without depending on the source")
  func displays() throws {
    let first = "C9229BE8-0C61-4A38-A339-AD5D6B07A215"
    let second = "F642B30E-6488-455C-B0C4-3B365F9D3D0E"
    #expect(RuleDisplayTarget(argument: "2")?.resolve(in: [first, second]) == second)
    #expect(RuleDisplayTarget(argument: "3")?.resolve(in: [first, second]) == nil)
    let target = try #require(RuleDisplayTarget(argument: second.lowercased()))
    #expect(target.resolve(in: [second, first]) == second)
    #expect(target.resolve(in: [first]) == nil)
  }

  @Test("Grid uses destination bounds and padding; display alone preserves relative placement")
  func geometry() throws {
    let source = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    let target = CGRect(x: 1_000, y: -100, width: 1_600, height: 1_000)
    let original = CGRect(x: 100, y: 100, width: 500, height: 400)
    let placement = WindowRulePlacement(
      grid: try #require(WindowGrid(argument: "2:1:1:0:1:1")),
      display: .index(2)
    )
    #expect(
      placement.frame(
        from: original,
        sourceBounds: source,
        targetBounds: target,
        settings: .defaults
      )
        == CGRect(x: 1_800, y: -100, width: 800, height: 1_000)
    )
    var settings = SpaceSettings.defaults
    settings.padding = SpacePadding(top: 10, bottom: 10, left: 20, right: 20)
    #expect(
      placement.frame(
        from: original,
        sourceBounds: source,
        targetBounds: target,
        settings: settings
      )
        == CGRect(x: 1_800, y: -90, width: 780, height: 980)
    )
    #expect(
      WindowRulePlacement(display: .index(2)).frame(
        from: original,
        sourceBounds: source,
        targetBounds: target,
        settings: .defaults
      )
        == CGRect(x: 1_220, y: 50, width: 500, height: 400)
    )
  }

  @Test("Grid rules reject exhausted destination bounds", arguments: [300, Int.max])
  func exhaustedGrid(value: Int) throws {
    let grid = try #require(WindowGrid(argument: "2:1:1:0:1:1"))
    let placement = WindowRulePlacement(grid: grid)
    let bounds = CGRect(x: -1440, y: -900, width: 300, height: 120)
    #expect(
      placement.frame(
        from: bounds,
        sourceBounds: bounds,
        targetBounds: bounds,
        settings: SpaceSettings(padding: .zero, gap: value)
      ) == nil
    )
  }

  @Test("Placement applies once, changes with matching actions, and expires on close")
  func oncePerChange() throws {
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

  @Test("Grid waits for floating participation; display still applies to tiled windows")
  func tilingEligibility() throws {
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

  @Test("Deferred placements retry; AX failures do not loop")
  func retries() throws {
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

  @Test("Minimized and fullscreen windows wait until available")
  func availability() throws {
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
  @Test("Display transfer refreshes layout membership and grids only a floating destination")
  func transfer() throws {
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

  @Test("A transfer to a tiled layout defers a previously applied grid")
  func gridAfterTransfer() throws {
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

}
