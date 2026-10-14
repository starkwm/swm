import CoreGraphics

/// Grid placement for resizing a window within visible screen bounds.
struct WindowGrid: Equatable {
  private let rows: Int
  private let columns: Int
  private let x: Int
  private let y: Int
  private let width: Int
  private let height: Int

  /// Create a clamped grid placement.
  init?(
    rows: Int,
    columns: Int,
    x: Int,
    y: Int,
    width: Int,
    height: Int
  ) {
    guard rows > 0, columns > 0 else { return nil }

    let x = min(max(0, x), columns - 1)
    let y = min(max(0, y), rows - 1)
    let width = min(max(1, width), columns - x)
    let height = min(max(1, height), rows - y)

    self.rows = rows
    self.columns = columns
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

  /// Calculate the target frame inside screen bounds using space padding and gap settings.
  func frame(in bounds: CGRect, settings: SpaceSettings) -> CGRect? {
    guard bounds.origin.x.isFinite, bounds.origin.y.isFinite,
      bounds.size.width.isFinite, bounds.size.height.isFinite,
      bounds.size.width > 0, bounds.size.height > 0
    else { return nil }

    let bounds = settings.tilingBounds(in: bounds)
    func axis(origin: CGFloat, length: CGFloat, count: Int, index: Int, span: Int) -> (
      CGFloat, CGFloat
    )? {
      guard length.isFinite, length > 0 else { return nil }
      if span == count { return (origin, length) }
      let gap = settings.tilingGap
      let cell = (length - gap * CGFloat(count - 1)) / CGFloat(count)
      guard cell.isFinite, cell > 0 else { return nil }
      return (
        origin + CGFloat(index) * (cell + gap), CGFloat(span) * cell + CGFloat(span - 1) * gap
      )
    }
    guard
      let horizontal = axis(
        origin: bounds.minX,
        length: bounds.width,
        count: columns,
        index: x,
        span: width
      ),
      let vertical = axis(
        origin: bounds.minY,
        length: bounds.height,
        count: rows,
        index: y,
        span: height
      )
    else { return nil }
    let frame = CGRect(x: horizontal.0, y: vertical.0, width: horizontal.1, height: vertical.1)
    guard frame.origin.x.isFinite, frame.origin.y.isFinite,
      frame.size.width.isFinite, frame.size.height.isFinite,
      frame.size.width > 0, frame.size.height > 0
    else { return nil }
    return frame
  }
}

extension WindowGrid {
  /// Parse a grid placement in `columns:rows:x:y:width:height` format.
  init?(argument: String) {
    let parts = argument.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

    guard
      parts.count == 6,
      let columns = Int(parts[0]),
      let rows = Int(parts[1]),
      let x = Int(parts[2]),
      let y = Int(parts[3]),
      let width = Int(parts[4]),
      let height = Int(parts[5])
    else {
      return nil
    }

    self.init(rows: rows, columns: columns, x: x, y: y, width: width, height: height)
  }
}
