/// A change to one padding side, written as `side=abs:<points>` or `side=rel:<points>`.
struct PaddingSideChange: Equatable {
  /// Accepted form of a side change, for error messages.
  static let form = "<side>=abs:<points> or <side>=rel:<points>, such as top=abs:8"

  /// Apply side changes to padding, keeping sides without a change.
  ///
  /// `context` names the command in the error thrown when an adjustment overflows.
  static func applying(
    _ changes: [Self],
    to padding: SpacePadding,
    context: String
  ) throws -> SpacePadding {
    var padding = padding
    for change in changes {
      padding[change.side] = try change.mode.applying(
        change.value,
        to: padding[change.side],
        context: context
      )
    }
    return padding.clamped()
  }

  /// Padding edge to change.
  let side: PaddingSide

  /// Whether the value replaces or adjusts the side.
  let mode: NumericChangeMode

  /// Points to set, or the signed points to add.
  let value: Int

  /// Parse a `side=mode:value` argument.
  init?(argument: String) {
    let assignment = argument.split(separator: "=", maxSplits: 1).map(String.init)
    guard assignment.count == 2, let side = PaddingSide(rawValue: assignment[0]) else {
      return nil
    }

    let change = assignment[1].split(separator: ":", omittingEmptySubsequences: false)
    guard
      change.count == 2,
      let mode = NumericChangeMode(rawValue: String(change[0])),
      let value = Int(change[1])
    else {
      return nil
    }

    self.side = side
    self.mode = mode
    self.value = value
  }
}

/// One edge of a Space padding setting.
enum PaddingSide: String, CaseIterable {
  case top
  case bottom
  case left
  case right
}

extension SpacePadding {
  /// The sides in the `--top <points> --bottom <points> ...` form the padding commands accept.
  var commandOptions: String {
    PaddingSide.allCases.map { "--\($0.rawValue) \(self[$0])" }.joined(separator: " ")
  }

  /// The padding on one edge.
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
