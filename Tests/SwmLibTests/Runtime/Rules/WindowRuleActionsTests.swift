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
}
