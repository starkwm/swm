import CoreGraphics
import Testing

@testable import SwmLib

@MainActor
@Suite("WindowRule")
struct WindowRuleTests {
  @Test(
    "parse: rejects malformed matching and management arguments",
    arguments: [
      [], ["manage=yes"], ["manage!=off"], ["manage=off", "app=["],
      ["manage=off", "app="], ["manage=off", "app=A", "app!=B"],
      ["manage=off", "unknown=value"], ["manage=off", "label=1"],
      ["manage=off", "manage=on"], ["manage"],
    ]
  )
  func parseRejectsMalformedMatchingAndManagementArguments(arguments: [String]) {
    #expect(throws: IPCCommandError.self) { try WindowRule.parse(arguments: arguments) }
  }

  @Test("parse: lists accepted keys for an unknown key")
  func parseListsAcceptedKeysForAnUnknownKey() {
    let error = #expect(throws: IPCCommandError.self) {
      try WindowRule.parse(arguments: ["manage=off", "application=Finder"])
    }
    #expect(
      error?.message
        == "invalid rule argument: application=Finder; expected key=value with one of label, app,"
        + " app!, title, title!, bundle-id, manage, grid, display"
    )
  }

  @Test(
    "parse: rejects invalid placement arguments",
    arguments: [
      ["grid=0:1:0:0:1:1"], ["grid=1:2:3"], ["grid=1:1:a:0:1:1"],
      ["display=0"], ["display=-1"], ["display=next"], ["display=not-a-uuid"],
      ["display=1", "display=2"], ["grid!=1:1:0:0:1:1"], ["app=Finder"],
    ]
  )
  func parseRejectsInvalidPlacementArguments(arguments: [String]) {
    #expect(throws: IPCCommandError.self) { try WindowRule.parse(arguments: arguments) }
  }

  @Test("matches: combines parsed filters and rejects missing identity")
  func matchesCombinesParsedFiltersAndRejectsMissingIdentity() throws {
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
}
