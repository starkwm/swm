import CoreGraphics

extension CGRect {
  var area: CGFloat {
    width * height
  }

  var isFiniteAndNonEmpty: Bool {
    origin.x.isFinite && origin.y.isFinite
      && size.width.isFinite && size.height.isFinite
      && size.width > 0 && size.height > 0
  }

  func matches(_ other: CGRect, tolerance: CGFloat) -> Bool {
    abs(minX - other.minX) <= tolerance
      && abs(minY - other.minY) <= tolerance
      && abs(width - other.width) <= tolerance
      && abs(height - other.height) <= tolerance
  }
}

extension Sequence {
  func largestIntersection(with rect: CGRect, frame: (Element) -> CGRect) -> Element? {
    self.max { lhs, rhs in
      rect.intersection(frame(lhs)).area < rect.intersection(frame(rhs)).area
    }
  }
}
