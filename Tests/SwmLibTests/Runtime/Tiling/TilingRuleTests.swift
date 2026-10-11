import CoreGraphics
import Testing

@testable import SwmLib

extension TilingTests {
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

  @Test("swapWindowWithMaster: skips rule floated leaves")
  func swapWindowWithMasterSkipsRuleFloatedLeaves() throws {
    var finder = window(id: 1)
    finder.app = "Finder"
    let tiling = makeTiling(
      windows: [finder, window(id: 2), window(id: 3)],
      memberships: [1: [10], 2: [10], 3: [10]]
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    try tiling.addRule(WindowRule.parse(arguments: ["app=^Finder$", "manage=off"]))
    #expect(tiling.masterWindowID(inLayoutContaining: 3) == 2)
    #expect(tiling.swapWindowWithMaster(3))
    #expect(tiling.masterWindowID(inLayoutContaining: 3) == 3)
    #expect(!tiling.swapWindowWithMaster(1))
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
}
