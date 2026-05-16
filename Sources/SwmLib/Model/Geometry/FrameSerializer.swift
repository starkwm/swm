import CoreGraphics

/// JSON-friendly rectangle representation.
struct FrameSerializer: Codable, Equatable {
  /// Minimum x-coordinate of the rectangle.
  let x: Double

  /// Minimum y-coordinate of the rectangle.
  let y: Double

  /// Rectangle width.
  let width: Double

  /// Rectangle height.
  let height: Double

  /// Create query geometry from a Core Graphics rectangle.
  init(_ rect: CGRect) {
    x = rect.origin.x
    y = rect.origin.y
    width = rect.size.width
    height = rect.size.height
  }
}
