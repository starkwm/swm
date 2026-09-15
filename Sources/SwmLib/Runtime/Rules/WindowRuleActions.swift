/// Independently resolved properties from all matching rules.
struct WindowRuleActions: Equatable {
  static func resolve(_ rules: [WindowRule], for window: TilingWindowSnapshot) -> Self {
    var result = Self()
    for rule in rules where rule.matches(window) {
      if let manage = rule.manage { result.manage = manage }
      if let grid = rule.grid { result.placement.grid = grid }
      if let display = rule.display { result.placement.display = display }
    }
    return result
  }

  var manage: Bool?
  var placement = WindowRulePlacement()
}

/// Placement properties are applied once per change; a new display also reapplies the grid.
struct WindowRulePlacement: Equatable {
  var grid: WindowGrid?
  var display: RuleDisplayTarget?

  var isEmpty: Bool { grid == nil && display == nil }
}

/// Deferred placements can retry when display or window facts become available.
enum WindowRulePlacementResult {
  case applied
  case deferred
  case failed
}
