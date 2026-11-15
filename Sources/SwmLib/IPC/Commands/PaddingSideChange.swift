struct PaddingSideChange: Equatable {
  static let form = "<side>=abs:<points> or <side>=rel:<points>, such as top=abs:8"

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

  let side: PaddingSide

  let change: NumericChange<Int>

  init?(argument: String) {
    let assignment = argument.split(separator: "=", maxSplits: 1).map(String.init)
    guard assignment.count == 2, let side = PaddingSide(rawValue: assignment[0]) else {
      return nil
    }

    guard let change = NumericChange(assignment[1], value: { Int($0) }) else { return nil }

    self.side = side
    self.change = change
  }
}

enum PaddingSide: String, CaseIterable {
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
