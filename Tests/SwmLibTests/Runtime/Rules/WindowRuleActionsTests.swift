import CoreGraphics
import Testing

@testable import SwmLib

@Suite("WindowRuleActions")
struct WindowRuleActionsTests {
  @Test("resolve: composes independent properties across matching rules")
  func resolveComposesIndependentPropertiesAcrossMatchingRules() throws {
    let rules = try [
      ["manage=off", "display=1"], ["grid=2:1:1:0:1:1"], ["display=2"],
      ["app=^Other$", "manage=on", "grid=1:1:0:0:1:1"],
    ].map { try WindowRule.parse(arguments: $0) }
    let resolved = WindowRuleActions.resolve(rules, for: window(id: 1))
    #expect(resolved.manage == false)
    #expect(resolved.placement.display == .index(2))
    #expect(resolved.placement.grid == WindowGrid(argument: "2:1:1:0:1:1"))
  }

  @Test("resolve: the later of space and display chooses the destination")
  func resolveTheLaterOfSpaceAndDisplayChoosesTheDestination() throws {
    let display = try WindowRule.parse(arguments: ["display=2"])
    let space = try WindowRule.parse(arguments: ["space=3"])
    let spaceLast = WindowRuleActions.resolve([display, space], for: window(id: 1)).placement
    #expect(spaceLast == WindowRulePlacement(display: nil, space: 3))
    let displayLast = WindowRuleActions.resolve([space, display], for: window(id: 1)).placement
    #expect(displayLast == WindowRulePlacement(display: .index(2), space: nil))
  }
}
