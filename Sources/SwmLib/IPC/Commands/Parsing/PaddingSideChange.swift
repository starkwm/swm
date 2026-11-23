public struct PaddingSideChange: Codable, Equatable, Sendable {
  static func applying(
    _ changes: [Self],
    to padding: SpacePadding,
    context: String
  ) throws -> SpacePadding {
    var padding = padding
    for change in changes {
      padding[change.side] = try change.change.applying(to: padding[change.side], context: context)
    }
    return padding.clamped()
  }

  public let side: PaddingSide

  public let change: NumericChange<Int>

  public init(side: PaddingSide, change: NumericChange<Int>) {
    self.side = side
    self.change = change
  }
}

public enum PaddingSide: String, CaseIterable, Codable, Sendable {
  case top
  case bottom
  case left
  case right
}

extension SpacePadding {
  var commandOptions: String {
    PaddingSide.allCases.map { "--\($0.rawValue) \(self[$0])" }.joined(separator: " ")
  }

  subscript(side: PaddingSide) -> Int {
    get {
      switch side {
      case .top: top
      case .bottom: bottom
      case .left: left
      case .right: right
      }
    }
    set {
      switch side {
      case .top: top = newValue
      case .bottom: bottom = newValue
      case .left: left = newValue
      case .right: right = newValue
      }
    }
  }
}
