import CoreGraphics

extension CGRect {
  /// Rectangle area.
  var area: CGFloat {
    width * height
  }

  /// Whether every origin and size component is finite and the size is positive.
  var isFiniteAndNonEmpty: Bool {
    origin.x.isFinite && origin.y.isFinite
      && size.width.isFinite && size.height.isFinite
      && size.width > 0 && size.height > 0
  }

  /// Return whether every frame component differs by no more than a tolerance.
  func matches(_ other: CGRect, tolerance: CGFloat) -> Bool {
    abs(minX - other.minX) <= tolerance
      && abs(minY - other.minY) <= tolerance
      && abs(width - other.width) <= tolerance
      && abs(height - other.height) <= tolerance
  }
}

extension Sequence {
  /// The element whose frame overlaps `rect` the most, or nil for an empty sequence.
  func largestIntersection(with rect: CGRect, frame: (Element) -> CGRect) -> Element? {
    self.max { lhs, rhs in
      rect.intersection(frame(lhs)).area < rect.intersection(frame(rhs)).area
    }
  }
}
