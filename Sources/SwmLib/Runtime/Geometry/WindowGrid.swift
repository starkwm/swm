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
  func frame(in bounds: CGRect, settings: SpaceSettings) -> CGRect {
    let padding = settings.paddingEnabled ? settings.padding : .zero
    let gap = settings.gapEnabled ? CGFloat(settings.gap) : 0

    var bounds = bounds
    bounds.origin.x += CGFloat(padding.left)
    bounds.size.width -= CGFloat(padding.left + padding.right)
    bounds.origin.y += CGFloat(padding.top)
    bounds.size.height -= CGFloat(padding.top + padding.bottom)

    if x > 0 {
      bounds.origin.x += gap
      bounds.size.width -= gap
    }

    if y > 0 {
      bounds.origin.y += gap
      bounds.size.height -= gap
    }

    if columns > x + width {
      bounds.size.width -= gap
    }

    if rows > y + height {
      bounds.size.height -= gap
    }

    let cellWidth = bounds.width / CGFloat(columns)
    let cellHeight = bounds.height / CGFloat(rows)

    return CGRect(
      x: bounds.minX + bounds.width - cellWidth * CGFloat(columns - x),
      y: bounds.minY + bounds.height - cellHeight * CGFloat(rows - y),
      width: cellWidth * CGFloat(width),
      height: cellHeight * CGFloat(height)
    )
  }
}
