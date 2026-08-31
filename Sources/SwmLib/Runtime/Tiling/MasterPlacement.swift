/// Edge occupied by the master pane in the master layout.
enum MasterPlacement: String, Equatable {
  /// Master column on the leading horizontal edge.
  case left

  /// Master column on the trailing horizontal edge.
  case right

  /// Master row on the upper edge.
  case top

  /// Master row on the lower edge.
  case bottom

  /// Return the adjacent placement in clockwise or counter-clockwise order.
  func cycled(in direction: CycleDirection) -> MasterPlacement {
    switch (self, direction) {
    case (.left, .next), (.right, .prev):
      return .top
    case (.top, .next), (.bottom, .prev):
      return .right
    case (.right, .next), (.left, .prev):
      return .bottom
    case (.bottom, .next), (.top, .prev):
      return .left
    }
  }
}
