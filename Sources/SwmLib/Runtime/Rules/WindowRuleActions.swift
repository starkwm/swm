/// Independently resolved properties from all matching rules.
struct WindowRuleActions: Equatable {
  static func resolve(_ rules: [WindowRule], for window: TilingWindowSnapshot) -> Self {
    var result = Self()
    for rule in rules where rule.matches(window) {
      if let manage = rule.manage { result.manage = manage }
      if let grid = rule.grid { result.placement.grid = grid }
      // Space and display both choose the destination, so the later one replaces the other.
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

/// Placement properties are applied once per change; a new display also reapplies the grid.
struct WindowRulePlacement: Equatable {
  var grid: WindowGrid?
  var display: RuleDisplayTarget?
  var space: Int?

  var isEmpty: Bool { grid == nil && display == nil && space == nil }
}

/// Deferred placements can retry when display or window facts become available.
enum WindowRulePlacementResult {
  case applied
  case deferred
  case failed
}
