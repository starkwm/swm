import CoreGraphics

/// A scrolling column width as a fraction of the padded display width.
enum ColumnWidthChange: Equatable {
  case absolute(CGFloat)
  case relative(CGFloat)
  case cycle(CycleDirection)

  static let presets: [CGFloat] = [1.0 / 3, 0.5, 2.0 / 3, 1]

  init?(argument: String) {
    if let direction = CycleDirection(rawValue: argument) {
      self = .cycle(direction)
      return
    }

    let components = argument.split(separator: ":", omittingEmptySubsequences: false)
    guard components.count == 2, let value = Double(components[1]), value.isFinite else {
      return nil
    }
    switch components[0] {
    case "abs": self = .absolute(CGFloat(value))
    case "rel": self = .relative(CGFloat(value))
    default: return nil
    }
  }

  func applying(to width: CGFloat) -> CGFloat {
    switch self {
    case .absolute(let value):
      return min(1, max(0.1, value))
    case .relative(let value):
      return min(1, max(0.1, width + value))
    case .cycle(.next):
      return Self.presets.first { $0 > width + 0.0001 } ?? Self.presets[0]
    case .cycle(.prev):
      return Self.presets.last { $0 < width - 0.0001 } ?? Self.presets.last!
    }
  }
}
