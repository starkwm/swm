struct WindowRuleActions: Equatable {
  static func resolve(_ rules: [WindowRule], for window: some WindowRuleSubject) -> Self {
    var result = Self()
    for rule in rules where rule.matches(window) {
      if let manage = rule.manage { result.manage = manage }
      if let grid = rule.grid { result.placement.grid = grid }
      if let display = rule.display {
        result.placement.display = display
        result.placement.space = nil
      }
      if let space = rule.space {
        result.placement.space = space
        result.placement.display = nil
      }
    }
    return result
  }

  var manage: Bool?
  var placement = WindowRulePlacement()
}

struct WindowRulePlacement: Equatable {
  var grid: WindowGrid?
  var display: RuleDisplayTarget?
  var space: Int?

  var isEmpty: Bool { grid == nil && display == nil && space == nil }
}

enum WindowRulePlacementResult {
  case applied
  case deferred
  case failed
}
