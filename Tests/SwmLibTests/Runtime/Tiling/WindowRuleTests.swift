import CoreGraphics
import Foundation
import Testing

@testable import SwmLib

@MainActor
@Suite("Window rules")
struct WindowRuleTests {
  @Test("Filters combine, preserve equals signs, and reject missing identity")
  func matching() throws {
    var candidate = window(id: 1)
    candidate.app = "Finder"
    candidate.title = "a!=b"
    candidate.bundleID = "com.apple.finder"
    let rule = try WindowRule.parse(arguments: [
      "app=^Finder$", "title=^a!=b$", "bundle-id=com.apple.finder", "manage=off",
    ])
    #expect(rule.matches(candidate))
    candidate.bundleID = "other"
    #expect(!rule.matches(candidate))
    let inverted = try WindowRule.parse(arguments: ["app!=^Finder$", "manage=off"])
    #expect(!inverted.matches(candidate))
    candidate.app = "Safari"
    #expect(inverted.matches(candidate))
    candidate.app = nil
    #expect(!inverted.matches(candidate))
  }

  @Test(
    "Malformed rules are rejected",
    arguments: [
      [], ["manage=yes"], ["manage!=off"], ["manage=off", "app=["],
      ["manage=off", "app="], ["manage=off", "app=A", "app!=B"],
      ["manage=off", "unknown=value"], ["manage=off", "label=1"],
      ["manage=off", "manage=on"], ["manage"],
    ]
  )
  func invalid(arguments: [String]) {
    #expect(throws: IPCCommandError.self) { try WindowRule.parse(arguments: arguments) }
  }

  @Test(
    "Last match wins; removal restores defaults in every tiling layout",
    arguments: [LayoutSelection.master, .monocle, .dwindle]
  )
  func precedence(layout: LayoutSelection) throws {
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

  @Test("Manual overrides survive rule edits but expire when the window closes")
  func manualOverrides() throws {
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

  @Test("New windows and title changes match before layout; fixed-size windows remain excluded")
  func lifecycle() throws {
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

  @Test("Master swaps skip a rule-floated first leaf")
  func masterSwap() throws {
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

  @Test("IPC validates mutations and lists indexed rules")
  func commands() throws {
    let tiling = makeTiling()
    let handler = RuleCommandHandler(tiling: tiling)
    func send(_ command: String, _ args: [String] = []) -> IPCResponse {
      handler.dispatch(IPCRequest(domain: .rule, command: command, args: args))
    }
    #expect(send("--add", ["label=test", "manage=off"]).ok)
    #expect(!send("--add", ["label=test", "manage=on"]).ok)
    #expect(!send("--add", ["app=[", "manage=off"]).ok)
    #expect(tiling.rules.count == 1)
    let listing = send("--list")
    #expect(listing.ok)
    let payload = try #require(
      JSONSerialization.jsonObject(with: Data(listing.message.utf8)) as? [[String: Any]]
    )
    #expect(payload.first?["index"] as? Int == 1)
    #expect((payload.first?["rule"] as? [String: String])?["label"] == "test")
    #expect(!send("--list", ["extra"]).ok)
    #expect(!send("--remove", [String(Int.min)]).ok)
    #expect(!send("--remove", ["0"]).ok)
    #expect(!send("--remove", ["missing"]).ok)
    #expect(!send("--remove", ["test", "extra"]).ok)
    #expect(!send("--unknown").ok)
    #expect(send("--remove", ["test"]).ok)
    #expect(tiling.rules.isEmpty)
  }
}
